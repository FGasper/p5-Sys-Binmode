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
if (OPID == OP_MKDIR) { \
fprintf(stderr, "in mkdir wrapper\n"); \
} \
    SV *svp = cop_hints_fetch_pvs(PL_curcop, HINT_KEY, 0);  \
                                                            \
    if (svp != &PL_sv_placeholder) {                        \
        dSP;                                                \
        dMARK_TOPMARK;                                      \
        dORIGMARK;                                          \
                                                            \
        while (++MARK <= SP) { \
if (OPID == OP_MKDIR) sv_dump(*MARK); \
MY_DOWNGRADE(aTHX_ MARK);      \
} \
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
#define MAKE_SP_WRAPPER(OPID)                           \
static OP* _wrapped_pp_##OPID(pTHX) {                       \
    SV *svp = cop_hints_fetch_pvs(PL_curcop, HINT_KEY, 0);  \
                                                            \
    if (svp != &PL_sv_placeholder) {                        \
        dSP;                                                \
        MY_DOWNGRADE(aTHX_ SP);                             \
    }                                                       \
                                                            \
    return ORIG_PL_ppaddr[OPID](aTHX);                      \
}


MAKE_LIST_WRAPPER(OP_OPEN);
MAKE_LIST_WRAPPER(OP_SYSOPEN);
MAKE_LIST_WRAPPER(OP_TRUNCATE);
MAKE_LIST_WRAPPER(OP_EXEC);
MAKE_LIST_WRAPPER(OP_SYSTEM);

MAKE_SP_WRAPPER(OP_BIND);
MAKE_SP_WRAPPER(OP_CONNECT);
MAKE_SP_WRAPPER(OP_SSOCKOPT);

MAKE_SP_WRAPPER(OP_LSTAT);
MAKE_SP_WRAPPER(OP_STAT);
MAKE_SP_WRAPPER(OP_FTRREAD);
MAKE_SP_WRAPPER(OP_FTRWRITE);
MAKE_SP_WRAPPER(OP_FTREXEC);
MAKE_SP_WRAPPER(OP_FTEREAD);
MAKE_SP_WRAPPER(OP_FTEWRITE);
MAKE_SP_WRAPPER(OP_FTEEXEC);
MAKE_SP_WRAPPER(OP_FTIS);
MAKE_SP_WRAPPER(OP_FTSIZE);
MAKE_SP_WRAPPER(OP_FTMTIME);
MAKE_SP_WRAPPER(OP_FTATIME);
MAKE_SP_WRAPPER(OP_FTCTIME);
MAKE_SP_WRAPPER(OP_FTROWNED);
MAKE_SP_WRAPPER(OP_FTEOWNED);
MAKE_SP_WRAPPER(OP_FTZERO);
MAKE_SP_WRAPPER(OP_FTSOCK);
MAKE_SP_WRAPPER(OP_FTCHR);
MAKE_SP_WRAPPER(OP_FTBLK);
MAKE_SP_WRAPPER(OP_FTFILE);
MAKE_SP_WRAPPER(OP_FTDIR);
MAKE_SP_WRAPPER(OP_FTPIPE);
MAKE_SP_WRAPPER(OP_FTSUID);
MAKE_SP_WRAPPER(OP_FTSGID);
MAKE_SP_WRAPPER(OP_FTSVTX);
MAKE_SP_WRAPPER(OP_FTLINK);
/* MAKE_SP_WRAPPER(OP_FTTTY); */
MAKE_SP_WRAPPER(OP_FTTEXT);
MAKE_SP_WRAPPER(OP_FTBINARY);
MAKE_SP_WRAPPER(OP_CHDIR);
MAKE_LIST_WRAPPER(OP_CHOWN);
MAKE_SP_WRAPPER(OP_CHROOT);
MAKE_LIST_WRAPPER(OP_UNLINK);
MAKE_LIST_WRAPPER(OP_CHMOD);
MAKE_LIST_WRAPPER(OP_UTIME);
MAKE_LIST_WRAPPER(OP_RENAME);
MAKE_LIST_WRAPPER(OP_LINK);
MAKE_LIST_WRAPPER(OP_SYMLINK);
MAKE_SP_WRAPPER(OP_READLINK);
MAKE_LIST_WRAPPER(OP_MKDIR);
MAKE_SP_WRAPPER(OP_RMDIR);
MAKE_SP_WRAPPER(OP_OPEN_DIR);

MAKE_SP_WRAPPER(OP_REQUIRE);
MAKE_SP_WRAPPER(OP_DOFILE);
MAKE_SP_WRAPPER(OP_BACKTICK);

/* (These appear to be fine already.)
MAKE_SP_WRAPPER(OP_GHBYADDR);
MAKE_SP_WRAPPER(OP_GNBYADDR);
*/

MAKE_LIST_WRAPPER(OP_SYSCALL);

/* ---------------------------------------------------------------------- */

#define MAKE_BOOT_WRAPPER(OPID)         \
if (OPID == OP_MKDIR) fprintf(stderr, "overwriting PL_ppaddr[OP_MKDIR] (%p) with %p)\n", PL_ppaddr[OPID], _wrapped_pp_##OPID); \
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
        initialized = true;

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
