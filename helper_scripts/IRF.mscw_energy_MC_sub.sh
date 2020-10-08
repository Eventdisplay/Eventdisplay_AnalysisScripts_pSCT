#!/bin/bash
# script to analyse MC files with lookup tables

# set observatory environmental variables
source "$EVNDISPSYS"/setObservatory.sh VTS

# parameters replaced by parent script using sed
INDIR=INPUTDIR
ODIR=OUTPUTDIR
TABFILE=TABLEFILE
ZA=ZENITHANGLE
NOISE=NOISELEVEL
WOBBLE=WOBBLEOFFSET
NROOTFILES=NFILES
ANAMETHOD=ANALYSISMETHOD
RUNNUMBER=RUNNMB
TMVADIR=TMVAPRODUCTS
RECID="RECONSTRUCTIONID"

# output directory
OSUBDIR="$ODIR/MSCW_RECID$RECID"
mkdir -p "$OSUBDIR"
chmod g+w "$OSUBDIR"
echo "Output directory for data products: " $OSUBDIR

# file names
OFILE="${ZA}deg_${WOBBLE}wob_NOISE${NOISE}"

# temporary directory
if [[ -n "$TMPDIR" ]]; then 
    DDIR="$TMPDIR/MSCW_${ZA}deg_${WOBBLE}deg_NOISE${NOISE}_ID${RECID}"
else
    DDIR="/tmp/MSCW_${ZA}deg_${WOBBLE}deg_NOISE${NOISE}_ID${RECID}"
fi
mkdir -p "$DDIR"
echo "Temporary directory: $DDIR"

# mscw_energy command line options
MOPT="-noNoTrigger -nomctree -writeReconstructedEventsOnly=1 -arrayrecid=$RECID -tablefile $TABFILE"
MOPT="$MOPT -runparameter $VERITAS_EVNDISP_AUX_DIR/ParameterFiles/MSCWENERGY.runparameter"
MOPT="$MOPT -minImages=1"
MOPT="$MOPT -redo_stereo_reconstruction -tmva_filename_stereo_reconstruction $TMVADIR/BDTDisp_BDT_ -tmva_filename_energy_reconstruction $TMVADIR/BDTDispEnergy_BDT_ -tmva_filename_core_reconstruction $TMVADIR/BDTDispCore_BDT_"
echo "MSCW options: $MOPT"

# run mscw_energy
if [[ $NROOTFILES == 1 ]]; then
      rm -f $OSUBDIR/$OFILE.log
      inputfilename="$INDIR/$RUNNBUMER.root"
      outputfilename="$DDIR/$OFILE.mscw.root"
      logfile="$OSUBDIR/$OFILE.mscw.log"
elif	[[ $NROOTFILES > 1 ]]; then
      ITER=$((SGE_TASK_ID - 1))
      RUNNUMBER=$((RUNNUMBER + $ITER))
      rm -f $OSUBDIR/${OFILE}$ITER.log
      inputfilename="$INDIR/$RUNNUMBER.root"
      outputfilename="$DDIR/${OFILE}$ITER.mscw.root"
      logfile="$OSUBDIR/${OFILE}$ITER.mscw.log"
fi
echo "$EVNDISPSYS/bin/mscw_energy $MOPT -inputfile $inputfilename -outputfile $outputfilename -noise=$NOISE"
$EVNDISPSYS/bin/mscw_energy $MOPT -inputfile $inputfilename -outputfile $outputfilename -noise=$NOISE &> $logfile

# cp results file back to data directory and clean up
outputbasename=$( basename $outputfilename )
cp -f -v $outputfilename $OSUBDIR/$outputbasename
rm -f "$outputfilename"
rmdir $DDIR
chmod g+w "$OSUBDIR/$outputbasename"
chmod g+w "$logfile"

exit
