#### Whole frame alignment with motioncorr: preparation, stack creation, CTF estimation, launching motioncorr

  * Run clean.sh script. Creation of a list of files for subsequent removal.
  * Run check.sh script. It will check if there is a corresponding frame stack for each total exposure.
  * Run movie_prep_parallel.sh script. It will create stacks from frames and the total exposure in parallel (8 cores).
  * Run movie_stack_ctf.sh script. It will launch CTFFIND4 in parallel on unaligned movie stacks.
  * Run movie_align.sh sript. Afterwards, check log files and sort stacks by average frame shift.
