#!/bin/bash
# submit evndisp for grisu/care simulations
#
#For pSCT camera configuration files, email pedro.batista@desy.de


# qsub parameters
#h_cpu=47:59:00; h_vmem=6000M; tmpdir_size=250G
h_cpu=47:59:00; h_vmem=6000M; tmpdir_size=450G

if [ $# -lt 7 ]; then
# begin help message
echo "
IRF generation: analyze simulation VBF files using evndisp 

IRF.evndisp_MC.sh <sim directory> <particle> <epoch> <atmosphere> <zenith> <offset angle> <NSB level> <sim type> <runparameter file> [events] [Small camera?]

required parameters:

    <sim directory>         directory containing simulation VBF files

    <particle>              type of particle used in simulation:
                            gamma (onSource) = 1, gamma (diffuse) = 12, electron = 2, proton = 3

    <epoch>                 array epoch (e.g., V4, V5, V6)
                            V4: array before T1 move (before Fall 2009)
                            V5: array after T1 move (Fall 2009 - Fall 2012)
                            V6: array after camera update (after Fall 2012)
    
    <atmosphere>            atmosphere model (61 = winter, 62 = summer)

    <zenith>                zenith angle of simulations [deg]

    <offset angle>          offset angle of simulations [deg]

    <NSB level>             NSB level of simulations [MHz]
    


optional parameters:
    
    [sim type]              file simulation type (expected sim type: CARE)

    [runparameter file]     file with integration window size and reconstruction cuts/methods, expected in $VERITAS_EVNDISP_AUX_DIR/ParameterFiles/

                            Default: EVNDISP.reconstruction.runparameter.pSCT
    

    [events]                number of events per division
                            (default: -1)

    [Small camera?]         Small camera simulations: yes = 1, no = 0
                            (default: 0)

Note: zenith angles, wobble offsets, and noise values are hard-coded into script

--------------------------------------------------------------------------------
"
#end help message
exit
fi

# Run init script
bash "$( cd "$( dirname "$0" )" && pwd )/helper_scripts/UTILITY.script_init.sh"
[[ $? != "0" ]] && exit 1

# EventDisplay version
EDVERSION=`$EVNDISPSYS/bin/evndisp --version | tr -d .`

# Parse command line arguments
SIMDIR=$1
PARTICLE=$2
EPOCH=$3
ATM=$4
ZA=$5
WOBBLE=$6
NOISE=$7
[[ "$8" ]] && SIMTYPE=$8 || SIMTYPE="CARE"
[[ "$9" ]] && ACUTS=$9 || ACUTS="EVNDISP.reconstruction.runparameter.pSCT"
[[ "${10}" ]] && NEVENTS=${10}  || NEVENTS=-1
[[ "${11}" ]] && SMALLCAM=${11}  || SMALLCAM=0

echo "NEVENTS = ${NEVENTS}" 

# Particle names
PARTICLE_NAMES=( [1]=gamma [2]=electron [3]=proton [12]=gamma_diffuse )
PARTICLE_TYPE=${PARTICLE_NAMES[$PARTICLE]}

# directory for run scripts
DATE=`date +"%y%m%d"`
LOGDIR="$VERITAS_USER_LOG_DIR/$DATE/EVNDISP.ANAMCVBF"
mkdir -p $LOGDIR

if [[ ${SMALLCAM} == "1" ]]; then
    CAMERA="SmallCamera"
    echo "Small camera? Yes."	
else
    CAMERA="FullCamera"
    echo "Small camera? No."	
fi

# output directory for evndisp products (will be manipulated more later in the script)
if [[ ! -z "$VERITAS_IRFPRODUCTION_DIR" ]]; then
    ODIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${SIMTYPE}/${CAMERA}/${EPOCH}_ATM${ATM}_${PARTICLE_TYPE}"
fi
# output dir
OPDIR=$ODIR"/ze"$ZA"deg_offset"$WOBBLE"deg_NSB"$NOISE"MHz"
mkdir -p $OPDIR
chmod -R g+w $OPDIR
echo -e "Output files will be written to:\n $OPDIR"

echo "Using runparameter file $ACUTS"

# Create a unique set of run numbers
if [[ ${SIMTYPE:0:5} = "GRISU" ]]; then
    [[ ${EPOCH:0:2} == "V4" ]] && RUNNUM="946500"
    [[ ${EPOCH:0:2} == "V5" ]] && RUNNUM="956500"
    [[ ${EPOCH:0:2} == "V6" ]] && RUNNUM="966500"
elif [ ${SIMTYPE:0:4} = "CARE" ]; then
    [[ ${EPOCH:0:2} == "V4" ]] && RUNNUM="941200"
    [[ ${EPOCH:0:2} == "V5" ]] && RUNNUM="951200"
    [[ ${EPOCH:0:2} == "V6" ]] && RUNNUM="961200"
fi

INT_WOBBLE=`echo "$WOBBLE*100" | bc | awk -F '.' '{print $1}'`
if [[ ${#INT_WOBBLE} -lt 2 ]]; then
   INT_WOBBLE="000"
elif [[ ${#INT_WOBBLE} -lt 3 ]]; then
   INT_WOBBLE="0$INT_WOBBLE"
fi

################################################################
# Find simulation file depending on the type of simulations
# VBFNAME - name of VBF file
# NOISEFILE - noise library (in grisu format)
VBFNAME="NO_VBFNAME"
NOISEFILE="NO_NOISEFILE"

if [ ${SIMTYPE:0:4} == "CARE" ]; then
    # input files (observe that these might need some adjustments)
    [[ $PARTICLE == "1" ]]  && VBFNAME="gamma_${ZA}deg_750m_${WOBBLE}wob_${NOISE}mhz_up_ATM${ATM}_part0"
    [[ $PARTICLE == "12" ]]  && VBFNAME="gamma_diffuse_${ZA}deg_750m_${WOBBLE}wob_${NOISE}mhz_up_ATM${ATM}_part0"
    [[ $PARTICLE == "2" ]] && VBFNAME="electron_${ZA}deg_750m_${WOBBLE}wob_${NOISE}mhz_up_ATM${ATM}_part0"
    [[ $PARTICLE == "3" ]] && VBFNAME="proton_${ZA}deg_750m_${WOBBLE}wob_${NOISE}mhz_up_ATM${ATM}_part0"
else
    echo "Wrong simulation type."
    exit
fi

# size of VBF file
FF=$(find $SIMDIR -maxdepth 1 \( -iname "${VBFNAME}*.zst" -o -iname "${VBFNAME}*.bz2" -o -iname "${VBFNAME}*.vbf" -o -iname "${VBFNAME}*.gz" \) -exec ls -ls -Llh {} \; | awk '{print $1}' | sed 's/,/./g')
echo "SIMDIR: $SIMDIR"
echo "VBFILE: ${VBFNAME} $FF"
echo "NOISEFILE: ${NOISEFILE}"
# tmpdir requires a safety factor of 2.5 (from unzipping VBF file)
TMSF=$(echo "${FF%?}*1.5" | bc)
if [[ ${NOISE} -eq 50 ]]; then
   TMSF=$(echo "${FF%?}*5.0" | bc)
fi
if [[ ${SIMTYPE:0:5} = "GRISU" ]]; then
   # GRISU files are bzipped and need more space (factor of ~14)
   TMSF=$(echo "${FF%?}*25.0" | bc)
fi

TMUNI=$(echo "${FF: -1}")
tmpdir_size=${TMSF%.*}$TMUNI
echo "Setting TMPDIR_SIZE to $tmpdir_size"
# determine number of jobs required
# (avoid many empty jobs)
if [[ ${TMSF%.*} -lt 40 ]]; then
   NEVENTS="-1"
fi
echo "Number of events per job: $NEVENTS"

# Job submission script
SUBSCRIPT="$EVNDISPSYS/scripts/pSCT/helper_scripts/IRF.evndisp_MC_sub_pSCT"

# make run script
FSCRIPT="$LOGDIR/evn-$EPOCH-$SIMTYPE-$ZA-$WOBBLE-$NOISE-ATM$ATM"
sed -e "s|DATADIR|$SIMDIR|" \
    -e "s|RUNNUMBER|$RUNNUM|" \
    -e "s|ZENITHANGLE|$ZA|" \
    -e "s|ATMOSPHERE|$ATM|" \
    -e "s|OUTPUTDIR|$OPDIR|" \
    -e "s|DECIMALWOBBLE|$WOBBLE|" \
    -e "s|INTEGERWOBBLE|$INT_WOBBLE|" \
    -e "s|NOISELEVEL|$NOISE|" \
    -e "s|ARRAYEPOCH|$EPOCH|" \
    -e "s|NENEVENT|$NEVENTS|" \
    -e "s|RECONSTRUCTIONRUNPARAMETERFILE|$ACUTS|" \
    -e "s|SIMULATIONTYPE|$SIMTYPE|" \
    -e "s|CAMERATYPE|$CAMERA|" \
    -e "s|VBFFFILE|$VBFNAME|" \
    -e "s|NOISEFFILE|$NOISEFILE|" \
    -e "s|PARTICLETYPE|$PARTICLE|" $SUBSCRIPT.sh > $FSCRIPT.sh

chmod u+x $FSCRIPT.sh
echo $FSCRIPT.sh

# run locally or on cluster
SUBC=`$EVNDISPSYS/scripts/VTS/helper_scripts/UTILITY.readSubmissionCommand.sh`
SUBC=`eval "echo \"$SUBC\""`
if [[ $SUBC == *qsub* ]]; then
    if [[ $NEVENTS -gt 0 ]]; then
	JOBID=`$SUBC -t 1-10 $FSCRIPT.sh`
    elif [[ $NEVENTS -lt 0 ]]; then
        JOBID=`$SUBC $FSCRIPT.sh`
    fi      
    echo "RUN $RUNNUM: JOBID $JOBID"
elif [[ $SUBC == *parallel* ]]; then
    echo "$FSCRIPT.sh &> $FSCRIPT.log" >> $LOGDIR/runscripts.dat
fi
                
exit

