{-# LANGUAGE
    EmptyDataDecls
  #-}
{-# OPTIONS_HADDOCK prune #-}

-- |Some type definitions for Subversion.

#include "HsSVN.h"

module Subversion.Types
    ( RevNum

    , APR_SIZE_T
    , APR_SSIZE_T
    , APR_STATUS_T

    , SVN_BOOLEAN_T
    , SVN_FILESIZE_T
    , SVN_NODE_KIND_T
    , SVN_REVNUM_T
    , SVN_VERSION_T

    , marshalBool
    , unmarshalBool

    , NodeKind(..) -- public
    , unmarshalNodeKind

    , Version(..) -- public
    , peekVersion
    )
    where

import           Data.Int
import           Data.Word
import           Foreign.C.String
import           Foreign.Ptr
import           Foreign.Storable

-- |@'RevNum'@ represents a revision number.
type RevNum = Int

type APR_SIZE_T     = #type apr_size_t
type APR_SSIZE_T    = #type apr_ssize_t
type APR_STATUS_T   = #type apr_status_t

type SVN_BOOLEAN_T   = #type svn_boolean_t
type SVN_FILESIZE_T  = #type svn_filesize_t
type SVN_NODE_KIND_T = #type svn_node_kind_t
type SVN_REVNUM_T    = #type svn_revnum_t
data SVN_VERSION_T


marshalBool :: Bool -> SVN_BOOLEAN_T
marshalBool True  = #const TRUE
marshalBool False = #const FALSE

unmarshalBool :: SVN_BOOLEAN_T -> Bool
unmarshalBool (#const TRUE ) = True
unmarshalBool (#const FALSE) = False
unmarshalBool _              = undefined

-- |@'NodeKind'@ represents a type of node in Subversion filesystem.
data NodeKind
    = NoNode   -- ^ The node is absent.
    | FileNode -- ^ The node is a file.
    | DirNode  -- ^ The node is a directory.
      deriving (Show, Eq)

unmarshalNodeKind :: SVN_NODE_KIND_T -> NodeKind
unmarshalNodeKind (#const svn_node_none) = NoNode
unmarshalNodeKind (#const svn_node_file) = FileNode
unmarshalNodeKind (#const svn_node_dir ) = DirNode
unmarshalNodeKind _                      = undefined

-- |@'Version'@ represents a version number.
data Version = Version {
      verMajor :: Int    -- ^ Major version number.
    , verMinor :: Int    -- ^ Minor version number.
    , verPatch :: Int    -- ^ Patch number.
    , verTag   :: String -- ^ The version tag.
    } deriving (Show, Eq)


peekVersion :: Ptr SVN_VERSION_T -> IO Version
peekVersion obj
    = do major <- peekVerMajor obj
         minor <- peekVerMinor obj
         patch <- peekVerPatch obj
         tag   <- peekVerTag   obj >>= peekCString
         return Version {
                      verMajor = major
                    , verMinor = minor
                    , verPatch = patch
                    , verTag   = tag
                    }


peekVerMajor :: Ptr SVN_VERSION_T -> IO Int
peekVerMajor = #peek svn_version_t, major

peekVerMinor :: Ptr SVN_VERSION_T -> IO Int
peekVerMinor = #peek svn_version_t, minor

peekVerPatch :: Ptr SVN_VERSION_T -> IO Int
peekVerPatch = #peek svn_version_t, patch

peekVerTag :: Ptr SVN_VERSION_T -> IO CString
peekVerTag = #peek svn_version_t, tag