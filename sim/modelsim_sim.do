set tbname tb_TSP_Core

proc all {} {
    global tbname
    sim
    if {[file isfile wave.do]} {
        do ./wave.do
    } else {
        add wave ./${tbname}/*
    }
    run -all
}

proc sim {} {
    global tbname

    if {![file isdirectory work]} {
        vlib work
    }

    if {![file isdirectory log]} {
        vlib log
    }

    vmap work work

    vlog -sv -incr \
         -v work \
         -override_timescale 1ns/10ps \
         -f modelsim_filelist.f \
         -l ./log/vlog.log

    vopt +acc +nospecify  work.${tbname} -o voptsim -l ./log/vopt.log
    vsim -c +nospecify voptsim -l ./log/vsim.log
}

proc asim {} {
    global tbname

    if {![file isdirectory work]} {
        vlib work
    }

    if {![file isdirectory log]} {
        vlib log
    }

    vmap work work

    vlog -sv -incr \
         -v work \
         -override_timescale 1ns/10ps \
         +define+SVA_TEST \
         -f ${tbname}.f \
         -l ./log/vlog.log

    vopt +acc +nospecify  work.${tbname} -o voptsim -l ./log/vopt.log
    vsim -c +nospecify voptsim \
         -l ./log/vsim.log \
         -assertDebug
    view assertions
}

proc re {} {
    global tbname
    restart -f
    if {[file isfile wave.do]} {
        do ./wave.do
    } else {
        add wave ./${tbname}/*
    }
    run -all
}

proc delete_wlf_files {} {
    # 获取当前目录下所有 wlf* 文件
    set wlf_files [glob -nocomplain -- "wlf*"]

    foreach file $wlf_files {
        # 检查是否是文件（避免误删目录）
        if {[file isfile $file]} {
            file delete -force $file
        }
    }
}

proc clear {} {
    quit -sim
    delete_wlf_files
    file delete -force {*}{
        vsim.wlf
        transcript
        *.vstf
        *.bak
    }
}

all