
if {$afe_db_enable == false} {
    set search_path         [concat $std_db_path $mem_db_path $search_path $sync_db_path $lpk_db_path]
    set target_library      [concat $std_db_list $afe_db_list]
} else {
    set search_path         [concat $std_db_path $afe_db_path $mem_db_path  $search_path $sync_db_path $io_db_path $lpk_db_path]
    set target_library      [concat $std_db_list $afe_db_list ]
}
set synthetic_library   [concat dw_foundation.sldb]
set link_library        [concat * $target_library ]
