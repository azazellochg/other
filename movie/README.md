#### Preprocessing of the movies, acquired on Falcon II camera with EPU*: preparation, stack creation, CTF estimation, motioncorr run

  * Run clean.sh script. It will create a list of unnecessary metadata files for subsequent removal.
  * Run check.sh script. It will check if there is a corresponding frame stack for each total exposure.
  * Run movie_prep_parallel.sh script. It will join frame stacks and total exposure into raw unaligned stacks, in parallel (8 cores).
  * Run movie_stack_ctf.sh script. It will launch CTFFIND4 in parallel (8 cores) on unaligned movie stacks. You can sort raw stacks by defocus and/or maximum detected resolution.
  * Run movie_align.sh sript. Afterwards, check log files and sort aligned sums and/or movies by average frame shift.

*Currently these scripts only support movies acquired as a single-stack in EPU.
