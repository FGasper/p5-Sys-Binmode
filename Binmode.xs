#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

static Perl_check_t old_checker_p = NULL;

OP * _wrapped_exec(pTHX) {
    dSP; dMARK; dORIGMARK;

    while (++MARK <= SP) {
        if (SvPOK(*MARK)) sv_utf8_downgrade(*MARK, FALSE);
    }

    MARK = ORIGMARK;

    return PL_ppaddr[OP_EXEC](aTHX);
}

static OP *downgrader(pTHX_ OP *op) {
/*
    assert( OP_TYPE_IS(plainop, OP_LIST) );
    LISTOP *op = (LISTOP *) plainop;

    fprintf(stderr, "in downgrader (op=%p)\n", op);

    OP *first = op->op_first;

    OP *cur = first;

    if (cur == NULL) return plainop;

    SVOP *svop;

    do {
warn("child opname: %s\n", OP_NAME(cur));
warn("child opdesc: %s\n", OP_DESC(cur));
warn("child opclass: %u\n", OP_CLASS(cur));
warn("child optype: %u\n", cur->op_type);
        if (OP_CLASS(cur) == OA_SVOP) {
warn("got an sv\n");
            svop = (SVOP *) cur;
            if (SvPOK(svop->op_sv)) {
warn("downgrading\n");
sv_dump(svop->op_sv);
                sv_utf8_downgrade(svop->op_sv, FALSE);
            }
        }
else {
warn("no sv\n");
}

        cur = OpSIBLING(cur);
    } while (cur);
warn("opname: %s\n", OP_NAME(plainop));
warn("opdesc: %s\n", OP_DESC(plainop));
warn("opclass: %u\n", OP_CLASS(plainop));
warn("optype: %u\n", plainop->op_type);
*/

    op->op_ppaddr = _wrapped_exec;

//    wrapop->op_next = op->op_next;

    return old_checker_p(aTHX_ op);
}

//----------------------------------------------------------------------

MODULE = Sys::Binmode     PACKAGE = Sys::Binmode

BOOT:
{

    wrap_op_checker(
        OP_EXEC,
        downgrader,
        &old_checker_p
    );
}
