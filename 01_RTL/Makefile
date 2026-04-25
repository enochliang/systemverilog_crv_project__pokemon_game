sim:
	vcs -full64 -sverilog \
		-timescale=1ns/100ps \
		-f filelist.f \
		-P ${VERDI_HOME}/share/PLI/VCS/LINUX64/novas.tab \
		   ${VERDI_HOME}/share/PLI/VCS/LINUX64/pli.a \
		-o simv \
		-l compile.log
	./simv

clean:
	rm -rf simv* *.fsdb *.log novas* nWaveLog csrc ucli.key
