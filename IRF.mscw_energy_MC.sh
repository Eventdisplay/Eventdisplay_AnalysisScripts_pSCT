#!/bin/bash
# script to analyse MC files with lookup tables

# qsub parameters
h_cpu=10:29:00; h_vmem=4000M; tmpdir_size=100G

if [ $# -lt 9 ]; then
# begin help message
echo "
IRF generation: analyze simulation evndisp ROOT files using mscw_energy 

IRF.mscw_energy_MC.sh <table file> <epoch> <atmosphere> <zenith> <offset angle> <NSB level> <Rec ID> [particle] [Small camera?]

required parameters:

    <table file>            mscw_energy lookup table file
    
    <epoch>                 array epoch (e.g., V4, V5, V6)
                            V4: array before T1 move (before Fall 2009)
                            V5: array after T1 move (Fall 2009 - Fall 2012)
                            V6: array after camera update (after Fall 2012)
    
    <atmosphere>            atmosphere model (61 = winter, 62 = summer)

    <zenith>                zenith angle of simulations [deg]

    <offset angle>          offset angle of simulations [deg]

    <NSB level>             NSB level of simulations [MHz]
    
    <Rec ID>                reconstruction ID
                            (see EVNDISP.reconstruction.runparameter)

    <runnumber>             e.g 961200

optional parameters:
    
    [particle]              type of particle used in simulation:
                            gamma = 1, proton = 14, alpha (helium) = 402
                            (default = 1  -->  gamma)

    [Small camera?]         Small camera simulations: yes = 1, no = 0
                            (default: 0)

                            
--------------------------------------------------------------------------------
"
#end help message
exit
fi

# Run init script
bash $(dirname "$0")"/helper_scripts/UTILITY.script_init.sh"
[[ $? != "0" ]] && exit 1

# EventDisplay version
"$EVNDISPSYS"/bin/mscw_energy --version  >/dev/null 2>/dev/null
if (($? == 0))
then
    EDVERSION=`"$EVNDISPSYS"/bin/mscw_energy --version | tr -d .`
else
    EDVERSION="g500"
fi

# Parse command line arguments
TABFILE=$1
TABFILE=${TABFILE%%.root}.root
echo "Table file: $TABFILE"
EPOCH=$2
ATM=$3
ZA=$4
WOBBLE=$5
NOISE=$6
RECID=$7
RUNNUMBER=$8
[[ "${9}" ]] && PARTICLE=${9} || PARTICLE=1
[[ "${10}" ]] && SMALLCAM=${10} || SMALLCAM="0"
SIMTYPE="CARE"

if [[ ${SMALLCAM} == "1" ]]; then
    CAMERA="SmallCamera"
    echo "Small camera? Yes."   
else
    CAMERA="FullCamera"
    echo "Small camera? No."    
fi


# Particle names
PARTICLE_NAMES=( [1]=gamma [2]=electron [14]=proton [402]=alpha )
PARTICLE_TYPE=${PARTICLE_NAMES[${PARTICLE}]}

echo "Particle type: $PARTICLE_TYPE "

# Check that table file exists
if [[ "$TABFILE" == `basename "$TABFILE"` ]]; then
    TABFILE="$VERITAS_EVNDISP_AUX_DIR/Tables/$TABFILE"
fi
if [[ ! -f "$TABFILE" ]]; then
    echo "Error, table file not found, exiting..."
    echo "$TABFILE"
    exit 1
fi

# input directory containing evndisp products
if [[ -n "$VERITAS_IRFPRODUCTION_DIR" ]]; then
    INDIR="$VERITAS_IRFPRODUCTION_DIR/${EDVERSION}/${SIMTYPE}/${CAMERA}/${EPOCH}_ATM${ATM}_${PARTICLE_TYPE}/ze${ZA}deg_offset${WOBBLE}deg_NSB${NOISE}MHz"
    echo "Input directory: $INDIR"
fi
if [[ ! -d $INDIR ]]; then
    echo -e "Error, could not locate input directory. Locations searched:\n $INDIR"
    exit 1
fi
echo "Input file directory: $INDIR"

NROOTFILES=$( ls -l "$INDIR"/*.root | wc -l )
echo "NROOTFILES $NROOTFILES"

# input directory containing TMVA for disp, energy and core reconstruction products

TMVADIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${SIMTYPE}/${CAMERA}/${EPOCH}_ATM${ATM}_gamma_diffuse/TMVA_AngularReconstruction/ze${ZA}deg_offset${WOBBLE}deg"

# directory for run scripts
DATE=`date +"%y%m%d"`
LOGDIR="$VERITAS_USER_LOG_DIR/$DATE/MSCW.ANATABLES/"
echo -e "Log files will be written to:\n $LOGDIR"
mkdir -p "$LOGDIR"

# Output file directory
if [[ -n "$VERITAS_IRFPRODUCTION_DIR" ]]; then
    ODIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/$SIMTYPE/${CAMERA}/${EPOCH}_ATM${ATM}_${PARTICLE_TYPE}"
fi
echo -e "Output files will be written to:\n $ODIR"

# Job submission script
SUBSCRIPT="$EVNDISPSYS/scripts/pSCT/helper_scripts/IRF.mscw_energy_MC_sub"

echo "Now processing zenith angle $ZA, wobble $WOBBLE, noise level $NOISE"

# make run script
FSCRIPT="$LOGDIR/MSCW-$EPOCH-$ZA-$WOBBLE-$NOISE-$PARTICLE-$(date +%s)"
sed -e "s|INPUTDIR|$INDIR|" \
    -e "s|OUTPUTDIR|$ODIR|" \
    -e "s|TABLEFILE|$TABFILE|" \
    -e "s|ZENITHANGLE|$ZA|" \
    -e "s|NOISELEVEL|$NOISE|" \
    -e "s|WOBBLEOFFSET|$WOBBLE|" \
    -e "s|NFILES|$NROOTFILES|" \
    -e "s|RUNNMB|$RUNNUMBER|" \
    -e "s|TMVAPRODUCTS|$TMVADIR|" \
    -e "s|RECONSTRUCTIONID|$RECID|" "$SUBSCRIPT.sh" > "$FSCRIPT.sh"

chmod u+x "$FSCRIPT.sh"
echo "Run script written to: $FSCRIPT"

# run locally or on cluster
SUBC=`$EVNDISPSYS/scripts/pSCT/helper_scripts/UTILITY.readSubmissionCommand.sh`
SUBC=`eval "echo \"$SUBC\""`
if [[ $SUBC == *"ERROR"* ]]; then
    echo "$SUBC"
    exit
fi
if [[ $SUBC == *qsub* ]]; then
    if [[ $NROOTFILES > 1 ]]; then
      JOBID=`$SUBC -t 1-$NROOTFILES $FSCRIPT.sh`
	 elif [[ $NROOTFILES == 1 ]]; then
	   JOBID=`$SUBC $FSCRIPT.sh`
    fi
    echo "JOBID: $JOBID"	  
elif [[ $SUBC == *parallel* ]]; then
    echo "$FSCRIPT.sh &> $FSCRIPT.log" >> $LOGDIR/runscripts.dat
elif [[ "$SUBC" == *simple* ]] ; then
    "$FSCRIPT.sh" | tee "$FSCRIPT.log"
fi

exit
