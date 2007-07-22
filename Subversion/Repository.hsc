{- -*- haskell -*- -}
module Subversion.Repository
    ( Repository

    , openRepository
    , createRepository
    , deleteRepository

    , getRepositoryFS

    , beginTxnForCommit
    , beginTxnForUpdate

    , commitTxn
    )
    where

import           Control.Monad
import           Data.Maybe
import           Foreign.C
import           Foreign.ForeignPtr
import           Foreign.Ptr
import           Foreign.Marshal.Alloc
import           Foreign.Storable
import           GHC.ForeignPtr   as GF
import           Subversion.Config
import           Subversion.FileSystem
import           Subversion.Hash
import           Subversion.Error
import           Subversion.Pool
import           Subversion.Types


newtype Repository = Repository (ForeignPtr SVN_REPOS_T)
data SVN_REPOS_T


foreign import ccall unsafe "svn_repos_open"
        _open :: Ptr (Ptr SVN_REPOS_T) -> CString -> Ptr APR_POOL_T -> IO (Ptr SVN_ERROR_T)

foreign import ccall unsafe "svn_repos_create"
        _create :: Ptr (Ptr SVN_REPOS_T) -> CString -> Ptr CChar -> Ptr CChar -> Ptr APR_HASH_T -> Ptr APR_HASH_T -> Ptr APR_POOL_T -> IO (Ptr SVN_ERROR_T)

foreign import ccall unsafe "svn_repos_delete"
        _delete :: CString -> Ptr APR_POOL_T -> IO (Ptr SVN_ERROR_T)

foreign import ccall unsafe "svn_repos_fs"
        _fs :: Ptr SVN_REPOS_T -> IO (Ptr SVN_FS_T)

foreign import ccall unsafe "svn_repos_fs_begin_txn_for_commit"
        _fs_begin_txn_for_commit :: Ptr (Ptr SVN_FS_TXN_T) -> Ptr SVN_REPOS_T -> SVN_REVNUM_T -> CString -> CString -> Ptr APR_POOL_T -> IO (Ptr SVN_ERROR_T)

foreign import ccall unsafe "svn_repos_fs_begin_txn_for_update"
        _fs_begin_txn_for_update :: Ptr (Ptr SVN_FS_TXN_T) -> Ptr SVN_REPOS_T -> SVN_REVNUM_T -> CString -> Ptr APR_POOL_T -> IO (Ptr SVN_ERROR_T)

foreign import ccall unsafe "svn_repos_fs_commit_txn"
        _fs_commit_txn :: Ptr CString -> Ptr SVN_REPOS_T -> Ptr SVN_REVNUM_T -> Ptr SVN_FS_TXN_T -> Ptr APR_POOL_T -> IO (Ptr SVN_ERROR_T)


wrapRepos :: Pool -> Ptr SVN_REPOS_T -> IO Repository
wrapRepos pool reposPtr
    = do repos <- newForeignPtr_ reposPtr
         GF.addForeignPtrConcFinalizer repos $ touchPool pool
         return $ Repository repos


withReposPtr :: Repository -> (Ptr SVN_REPOS_T -> IO a) -> IO a
withReposPtr (Repository repos) = withForeignPtr repos


touchRepos :: Repository -> IO ()
touchRepos (Repository repos) = touchForeignPtr repos


openRepository :: FilePath -> IO Repository
openRepository path
    = do pool <- newPool
         alloca $ \ reposPtrPtr ->
             withCString path $ \ pathPtr ->
                 withPoolPtr pool $ \ poolPtr ->
                     do svnErr $ _open reposPtrPtr pathPtr poolPtr
                        wrapRepos pool =<< peek reposPtrPtr


createRepository :: FilePath -> Maybe (Hash Config) -> Maybe (Hash String) -> IO Repository
createRepository path config fsConfig
    = do pool <- newPool
         alloca $ \ reposPtrPtr ->
             withCString path $ \ pathPtr ->
                 withPoolPtr pool $ \ poolPtr ->
                     do svnErr (_create
                                reposPtrPtr
                                pathPtr
                                nullPtr
                                nullPtr
                                (unsafeHashToPtr' config)
                                (unsafeHashToPtr' fsConfig)
                                poolPtr)
                        repos <- wrapRepos pool =<< peek reposPtrPtr

                        -- config と fsConfig には、repos が死ぬまでは
                        -- 生きてゐて慾しい。
                        when (isJust config || isJust fsConfig)
                             $ GF.addForeignPtrConcFinalizer (case repos of Repository x -> x)
                                   $ do touchHash' config
                                        touchHash' fsConfig

                        return repos


deleteRepository :: FilePath -> IO ()
deleteRepository path
    = do pool <- newPool
         withCString path $ \ pathPtr ->
             withPoolPtr pool $ \ poolPtr ->
                 svnErr $ _delete pathPtr poolPtr


getRepositoryFS :: Repository -> IO FileSystem
getRepositoryFS (Repository repos)
    = withForeignPtr repos $ \ reposPtr ->
      -- svn_fs_t* より先に svn_repos_t* が解放されては困る
      _fs reposPtr >>= wrapFS repos


beginTxnForCommit :: Repository -> Int -> String -> String -> IO Transaction
beginTxnForCommit repos revNum author logMsg
    = do pool <- newPool
         alloca $ \ txnPtrPtr ->
             withReposPtr repos $ \ reposPtr  ->
             withCString author $ \ authorPtr ->
             withCString logMsg $ \ logMsgPtr ->
             withPoolPtr pool   $ \ poolPtr   ->
             (svnErr $
              _fs_begin_txn_for_commit
              txnPtrPtr
              reposPtr
              (fromIntegral revNum)
              authorPtr
              logMsgPtr
              poolPtr)
             >>  peek txnPtrPtr
             >>= (wrapTxn $
                  -- txn は pool にも repos にも依存する。
                  touchPool pool >> touchRepos repos)
             

beginTxnForUpdate :: Repository -> Int -> String -> IO Transaction
beginTxnForUpdate repos revNum author
    = do pool <- newPool
         alloca $ \ txnPtrPtr ->
             withReposPtr repos $ \ reposPtr  ->
             withCString author $ \ authorPtr ->
             withPoolPtr pool   $ \ poolPtr   ->
             (svnErr $
              _fs_begin_txn_for_update
              txnPtrPtr
              reposPtr
              (fromIntegral revNum)
              authorPtr
              poolPtr)
             >>  peek txnPtrPtr
             >>= (wrapTxn $ 
                  -- txn は pool にも repos にも依存する。
                  touchPool pool >> touchRepos repos)


commitTxn :: Repository -> Transaction -> IO (Either FilePath Int)
commitTxn repos txn
    = do pool <- newPool
         alloca $ \ conflictPathPtrPtr ->
             withReposPtr repos $ \ reposPtr  ->
             alloca             $ \ newRevPtr ->
             withTxnPtr  txn    $ \ txnPtr    ->
             withPoolPtr pool   $ \ poolPtr   ->
             do err <- wrapSvnError =<< (_fs_commit_txn
                                         conflictPathPtrPtr
                                         reposPtr
                                         newRevPtr
                                         txnPtr
                                         poolPtr)
                case err of
                  Nothing
                      -> liftM (Right . fromIntegral) (peek newRevPtr)

                  Just e
                      -> if svnErrCode e == FsConflict then
                             return . Left =<< peekCString =<< peek conflictPathPtrPtr
                         else
                             throwSvnErr e