#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

static Perl_ppaddr_t MY_PL_ppaddr[OP_max];

#define MYPKG "Sys::Binmode"
#define HINT_KEY MYPKG "/enabled"

/* An idempotent variant of dMARK that allows us to inspect the
   mark stack without changing it: */
#ifndef dMARK_TOPMARK
    #define dMARK_TOPMARK SV **mark = PL_stack_base + TOPMARK
#endif

#define MAKE_WRAPPER(OPID)                                  \
static OP* _wrapped_pp_##OPID(pTHX) {                       \
    SV *svp = cop_hints_fetch_pvs(PL_curcop, HINT_KEY, 0);  \
                                                            \
    if (svp && svp != &PL_sv_placeholder) {                 \
        dSP;                                                \
        dMARK_TOPMARK;                                      \
        dORIGMARK;                                          \
                                                            \
        while (++MARK <= SP)                                \
            if (SvPOK(*MARK))                               \
                sv_utf8_downgrade(*MARK, FALSE);            \
                                                            \
        MARK = ORIGMARK;                                    \
    }                                                       \
                                                            \
    return MY_PL_ppaddr[OPID](aTHX);                        \
}

MAKE_WRAPPER(OP_OPEN);
MAKE_WRAPPER(OP_SYSOPEN);
MAKE_WRAPPER(OP_TRUNCATE);
MAKE_WRAPPER(OP_EXEC);
MAKE_WRAPPER(OP_SYSTEM);

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
/* MAKE_WRAPPER(OP_FTTTY); */
MAKE_WRAPPER(OP_FTTEXT);
MAKE_WRAPPER(OP_FTBINARY);
MAKE_WRAPPER(OP_CHDIR);
MAKE_WRAPPER(OP_CHOWN);
MAKE_WRAPPER(OP_CHROOT);
MAKE_WRAPPER(OP_UNLINK);
MAKE_WRAPPER(OP_CHMOD);
MAKE_WRAPPER(OP_UTIME);
MAKE_WRAPPER(OP_RENAME);
MAKE_WRAPPER(OP_LINK);
MAKE_WRAPPER(OP_SYMLINK);
MAKE_WRAPPER(OP_READLINK);
MAKE_WRAPPER(OP_MKDIR);
MAKE_WRAPPER(OP_RMDIR);
MAKE_WRAPPER(OP_OPEN_DIR);

MAKE_WRAPPER(OP_REQUIRE);
MAKE_WRAPPER(OP_DOFILE);

/* (These appear to be fine already.)
MAKE_WRAPPER(OP_GHBYADDR);
MAKE_WRAPPER(OP_GNBYADDR);
*/

MAKE_WRAPPER(OP_SYSCALL);

/* ---------------------------------------------------------------------- */

#define MAKE_BOOT_WRAPPER(OPID) \
PL_ppaddr[OPID] = _wrapped_pp_##OPID

//----------------------------------------------------------------------

MODULE = Sys::Binmode     PACKAGE = Sys::Binmode

PROTOTYPES: DISABLE

BOOT:
{
    unsigned i;
    for (i=0; i<OP_max; i++) MY_PL_ppaddr[i] = PL_ppaddr[i];

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

    /* (These appear to be fine already.)
    MAKE_BOOT_WRAPPER(OP_GHBYADDR);
    MAKE_BOOT_WRAPPER(OP_GNBYADDR);
    */

    MAKE_BOOT_WRAPPER(OP_SYSCALL);
}
