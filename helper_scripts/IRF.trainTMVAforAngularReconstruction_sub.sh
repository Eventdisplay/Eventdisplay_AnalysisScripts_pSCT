#!/bin/bash
# script to train TMVA (BDTs) for angular reconstruction

# set observatory environmental variables
source "${EVNDISPSYS}"/setObservatory.sh VTS

# parameters replaced by parent script using sed
INDIR=EVNDISPFILE
ODIR=OUTPUTDIR
ONAME=BDTFILE
BDTTARGET=TARGETBDT
TELID=IDTEL

# train
rm -f "${ODIR}/${ONAME}*"

ls ${INDIR}/*[0-9].root >| "${ODIR}/INPUT_LIST.txt"

# fraction of events to use for training,
# remaining events will be used for testing
TRAINTESTFRACTION=0.5

"${EVNDISPSYS}"/bin/trainTMVAforAngularReconstruction "${ODIR}/INPUT_LIST.txt" "${ODIR}" "${TRAINTESTFRACTION}" 0 "${TELID}" "${BDTTARGET}" > "$ODIR/$ONAME.log"


exit
