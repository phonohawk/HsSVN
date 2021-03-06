#ifndef HSSVN_H_INCLUDED
#define HSSVN_H_INCLUDED
#include <apr_errno.h>
#include <apr_hash.h>
#include <apr_md5.h>
#include <svn_error.h>
#include <svn_error_codes.h>
#include <svn_fs.h>
#include <svn_pools.h>
#include <svn_repos.h>
#include <svn_version.h>

/* initialization ************************************************************ */
int HsSVN_initialize();

/* pools ********************************************************************* */
apr_pool_t* HsSVN_svn_pool_create(apr_pool_t* parent);
void HsSVN_svn_pool_destroy(apr_pool_t* pool);

#endif
