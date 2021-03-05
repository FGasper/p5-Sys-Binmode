#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdbool.h>

#include "ppport.h"

/* A duplicate of PL_ppaddr as we find it at BOOT time.
   We can thus overwrite PL_ppaddr with our own wrapper functions.
   This interacts better with wrap_op_checker(), which doesn’t provide
   a good way to call the op’s (now-overwritten) op_ppaddr callback.
*/
static Perl_ppaddr_t ORIG_PL_ppaddr[OP_max];

/* A lookup of op number to a bitmask for which args are ints. */
static unsigned OP_STRING_ARG_MASK[OP_max];

#define ARG_INDEX_MASK(idx) (1 << idx)

#define MYPKG "Sys::Binmode"
#define HINT_KEY MYPKG "/enabled"

/* An idempotent variant of dMARK that allows us to inspect the
   mark stack without changing it: */
#ifndef dMARK_TOPMARK
    #define dMARK_TOPMARK SV **mark = PL_stack_base + TOPMARK
#endif

#define DOWNGRADE_SVPV(sv) if (SvPOK(sv)) sv_utf8_downgrade(sv, FALSE)

static inline void MY_DOWNGRADE(pTHX_ SV** svp) {
    if (UNLIKELY(SvGAMAGIC(*svp))) {

        /* If the parameter in question is magical/overloaded
           then we need to fetch the (string) value, downgrade it,
           then replace the overloaded object in the stack with
           our fetched value.
        */

        SV* replacement = sv_newmortal();

        /* fetches the overloadeed value */
        sv_copypv(replacement, *svp);

        DOWNGRADE_SVPV(replacement);

        *svp = replacement;
    }

    /* NB: READONLY strings can be downgraded. */
    else DOWNGRADE_SVPV(*svp);
}

#define MAKE_LIST_WRAPPER(OPID)                             \
static OP* _wrapped_pp_##OPID(pTHX) {                       \
    SV *svp = cop_hints_fetch_pvs(PL_curcop, HINT_KEY, 0);  \
                                                            \
    if (svp != &PL_sv_placeholder) {                        \
        dSP;                                                \
        dMARK_TOPMARK;                                      \
        dORIGMARK;                                          \
                                                            \
        while (++MARK <= SP) MY_DOWNGRADE(aTHX_ MARK);      \
                                                            \
        MARK = ORIGMARK;                                    \
    }                                                       \
                                                            \
    return ORIG_PL_ppaddr[OPID](aTHX);                      \
}

/* Ops that take only 1 arg don’t always set a mark. We can’t
   just iterate from MARK to SP in those cases; we just have to
   work with the stack pointer (SP) directly.
*/
#define MAKE_WRAPPER(OPID)                                  \
static OP* _wrapped_pp_##OPID(pTHX) {                       \
    SV *svp = cop_hints_fetch_pvs(PL_curcop, HINT_KEY, 0);  \
                                                            \
    if (svp != &PL_sv_placeholder) {                        \
    fprintf(stderr, "maxarg: %u\n", MAXARG); \
        dSP;                                                \
                                                            \
        /* 1st arg */                                       \
        if (OP_STRING_ARG_MASK[OPID] & 1)                   \
            MY_DOWNGRADE(aTHX_ SP - MAXARG + 1);            \
                                                            \
        /* 2nd arg */                                       \
        if (OP_STRING_ARG_MASK[OPID] & 2)                   \
            MY_DOWNGRADE(aTHX_ SP - MAXARG + 2);                     \
                                                            \
        /* 3rd arg is never needed */                       \
                                                            \
        /* 4th arg */                                       \
        if (OP_STRING_ARG_MASK[OPID] & 8)                   \
            MY_DOWNGRADE(aTHX_ SP - MAXARG + 4);                     \
    }                                                       \
                                                            \
    return ORIG_PL_ppaddr[OPID](aTHX);                      \
}

/* These definitely take a list, so we depend on MARK. */
MAKE_LIST_WRAPPER(OP_OPEN);
MAKE_LIST_WRAPPER(OP_EXEC);
MAKE_LIST_WRAPPER(OP_SYSTEM);

MAKE_WRAPPER(OP_SYSOPEN);

MAKE_WRAPPER(OP_TRUNCATE);

MAKE_WRAPPER(OP_BIND);
MAKE_WRAPPER(OP_CONNECT);
MAKE_WRAPPER(OP_SSOCKOPT);

MAKE_WRAPPER(OP_LSTAT);
MAKE_WRAPPER(OP_STAT);
MAKE_WRAPPER(OP_FTRREAD);
MAKE_WRAPPER(OP_FTRWRITE);
MAKE_WRAPPER(OP_FTREXEC);
MAKE_WRAPPER(OP_FTEREAD);
MAKE_WRAPPER(OP_FTEWRITE);
MAKE_WRAPPER(OP_FTEEXEC);
MAKE_WRAPPER(OP_FTIS);
MAKE_WRAPPER(OP_FTSIZE);
MAKE_WRAPPER(OP_FTMTIME);
MAKE_WRAPPER(OP_FTATIME);
MAKE_WRAPPER(OP_FTCTIME);
MAKE_WRAPPER(OP_FTROWNED);
MAKE_WRAPPER(OP_FTEOWNED);
MAKE_WRAPPER(OP_FTZERO);
MAKE_WRAPPER(OP_FTSOCK);
MAKE_WRAPPER(OP_FTCHR);
MAKE_WRAPPER(OP_FTBLK);
MAKE_WRAPPER(OP_FTFILE);
MAKE_WRAPPER(OP_FTDIR);
MAKE_WRAPPER(OP_FTPIPE);
MAKE_WRAPPER(OP_FTSUID);
MAKE_WRAPPER(OP_FTSGID);
MAKE_WRAPPER(OP_FTSVTX);
MAKE_WRAPPER(OP_FTLINK);
/* MAKE_SCALAR_WRAPPER(OP_FTTTY); */
MAKE_WRAPPER(OP_FTTEXT);
MAKE_WRAPPER(OP_FTBINARY);
MAKE_WRAPPER(OP_CHDIR);
MAKE_LIST_WRAPPER(OP_CHOWN);
MAKE_WRAPPER(OP_CHROOT);
MAKE_LIST_WRAPPER(OP_UNLINK);
MAKE_LIST_WRAPPER(OP_CHMOD);
MAKE_LIST_WRAPPER(OP_UTIME);
MAKE_WRAPPER(OP_RENAME);
MAKE_WRAPPER(OP_LINK);
MAKE_WRAPPER(OP_SYMLINK);
MAKE_WRAPPER(OP_READLINK);

MAKE_WRAPPER(OP_MKDIR);

MAKE_WRAPPER(OP_RMDIR);
MAKE_WRAPPER(OP_OPEN_DIR);

MAKE_WRAPPER(OP_REQUIRE);
MAKE_WRAPPER(OP_DOFILE);
MAKE_WRAPPER(OP_BACKTICK);

/* (These appear to be fine already.)
MAKE_SCALAR_WRAPPER(OP_GHBYADDR);
MAKE_SCALAR_WRAPPER(OP_GNBYADDR);
*/

MAKE_LIST_WRAPPER(OP_SYSCALL);

/* ---------------------------------------------------------------------- */

#define MAKE_BOOT_WRAPPER(OPID)         \
ORIG_PL_ppaddr[OPID] = PL_ppaddr[OPID]; \
PL_ppaddr[OPID] = _wrapped_pp_##OPID;

//----------------------------------------------------------------------

bool initialized = false;

MODULE = Sys::Binmode     PACKAGE = Sys::Binmode

PROTOTYPES: DISABLE

BOOT:
    /* In theory this is for PL_check rather than PL_ppaddr, but per
       Paul Evans in practice this mutex gets used for other stuff, too.
       Paul says a race here should be exceptionally rare, so for pre-5.16
       perls (which lack this mutex) let’s just skip it.
    */
#ifdef OP_CHECK_MUTEX_LOCK
    OP_CHECK_MUTEX_LOCK;
#endif
    if (!initialized) {
        initialized = 1;

        OP_STRING_ARG_MASK[OP_SYSOPEN] = ARG_INDEX_MASK(1);
        OP_STRING_ARG_MASK[OP_TRUNCATE] = ARG_INDEX_MASK(0);

        OP_STRING_ARG_MASK[OP_BIND] = ARG_INDEX_MASK(1);
        OP_STRING_ARG_MASK[OP_CONNECT] = ARG_INDEX_MASK(1);
        OP_STRING_ARG_MASK[OP_SSOCKOPT] = ARG_INDEX_MASK(3);

        OP_STRING_ARG_MASK[OP_LSTAT] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_STAT] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTRREAD] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTRWRITE] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTREXEC] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTEREAD] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTEWRITE] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTEEXEC] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTIS] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTSIZE] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTMTIME] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTATIME] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTCTIME] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTROWNED] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTEOWNED] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTZERO] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTSOCK] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTCHR] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTBLK] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTFILE] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTDIR] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTPIPE] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTSUID] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTSGID] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTSVTX] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTLINK] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTTEXT] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTBINARY] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_CHDIR] = ARG_INDEX_MASK(0);

        OP_STRING_ARG_MASK[OP_FTTEXT] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_FTBINARY] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_CHDIR] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_CHROOT] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_RENAME] = ARG_INDEX_MASK(0) | ARG_INDEX_MASK(1);
        OP_STRING_ARG_MASK[OP_LINK] = ARG_INDEX_MASK(0) | ARG_INDEX_MASK(1);
        OP_STRING_ARG_MASK[OP_SYMLINK] = ARG_INDEX_MASK(0) | ARG_INDEX_MASK(1);
        OP_STRING_ARG_MASK[OP_READLINK] = ARG_INDEX_MASK(0);

        OP_STRING_ARG_MASK[OP_MKDIR] = ARG_INDEX_MASK(0);

        OP_STRING_ARG_MASK[OP_RMDIR] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_OPEN_DIR] = ARG_INDEX_MASK(1);

        OP_STRING_ARG_MASK[OP_REQUIRE] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_DOFILE] = ARG_INDEX_MASK(0);
        OP_STRING_ARG_MASK[OP_BACKTICK] = ARG_INDEX_MASK(0);

        HV *stash = gv_stashpv(MYPKG, FALSE);
        newCONSTSUB(stash, "_HINT_KEY", newSVpvs(HINT_KEY));

        MAKE_BOOT_WRAPPER(OP_OPEN);
        MAKE_BOOT_WRAPPER(OP_SYSOPEN);
        MAKE_BOOT_WRAPPER(OP_TRUNCATE);
        MAKE_BOOT_WRAPPER(OP_EXEC);
        MAKE_BOOT_WRAPPER(OP_SYSTEM);

        MAKE_BOOT_WRAPPER(OP_BIND);
        MAKE_BOOT_WRAPPER(OP_CONNECT);
        MAKE_BOOT_WRAPPER(OP_SSOCKOPT);

        MAKE_BOOT_WRAPPER(OP_LSTAT);
        MAKE_BOOT_WRAPPER(OP_STAT);
        MAKE_BOOT_WRAPPER(OP_FTRREAD);
        MAKE_BOOT_WRAPPER(OP_FTRWRITE);
        MAKE_BOOT_WRAPPER(OP_FTREXEC);
        MAKE_BOOT_WRAPPER(OP_FTEREAD);
        MAKE_BOOT_WRAPPER(OP_FTEWRITE);
        MAKE_BOOT_WRAPPER(OP_FTEEXEC);
        MAKE_BOOT_WRAPPER(OP_FTIS);
        MAKE_BOOT_WRAPPER(OP_FTSIZE);
        MAKE_BOOT_WRAPPER(OP_FTMTIME);
        MAKE_BOOT_WRAPPER(OP_FTATIME);
        MAKE_BOOT_WRAPPER(OP_FTCTIME);
        MAKE_BOOT_WRAPPER(OP_FTROWNED);
        MAKE_BOOT_WRAPPER(OP_FTEOWNED);
        MAKE_BOOT_WRAPPER(OP_FTZERO);
        MAKE_BOOT_WRAPPER(OP_FTSOCK);
        MAKE_BOOT_WRAPPER(OP_FTCHR);
        MAKE_BOOT_WRAPPER(OP_FTBLK);
        MAKE_BOOT_WRAPPER(OP_FTFILE);
        MAKE_BOOT_WRAPPER(OP_FTDIR);
        MAKE_BOOT_WRAPPER(OP_FTPIPE);
        MAKE_BOOT_WRAPPER(OP_FTSUID);
        MAKE_BOOT_WRAPPER(OP_FTSGID);
        MAKE_BOOT_WRAPPER(OP_FTSVTX);
        MAKE_BOOT_WRAPPER(OP_FTLINK);
        /* MAKE_BOOT_WRAPPER(OP_FTTTY); */
        MAKE_BOOT_WRAPPER(OP_FTTEXT);
        MAKE_BOOT_WRAPPER(OP_FTBINARY);
        MAKE_BOOT_WRAPPER(OP_CHDIR);
        MAKE_BOOT_WRAPPER(OP_CHOWN);
        MAKE_BOOT_WRAPPER(OP_CHROOT);
        MAKE_BOOT_WRAPPER(OP_UNLINK);
        MAKE_BOOT_WRAPPER(OP_CHMOD);
        MAKE_BOOT_WRAPPER(OP_UTIME);
        MAKE_BOOT_WRAPPER(OP_RENAME);
        MAKE_BOOT_WRAPPER(OP_LINK);
        MAKE_BOOT_WRAPPER(OP_SYMLINK);
        MAKE_BOOT_WRAPPER(OP_READLINK);
        MAKE_BOOT_WRAPPER(OP_MKDIR);
        MAKE_BOOT_WRAPPER(OP_RMDIR);
        MAKE_BOOT_WRAPPER(OP_OPEN_DIR);

        MAKE_BOOT_WRAPPER(OP_REQUIRE);
        MAKE_BOOT_WRAPPER(OP_DOFILE);
        MAKE_BOOT_WRAPPER(OP_BACKTICK);

        /* (These appear to be fine already.)
        MAKE_BOOT_WRAPPER(OP_GHBYADDR);
        MAKE_BOOT_WRAPPER(OP_GNBYADDR);
        */

        MAKE_BOOT_WRAPPER(OP_SYSCALL);
    }
#ifdef OP_CHECK_MUTEX_UNLOCK
    OP_CHECK_MUTEX_UNLOCK;
#endif
