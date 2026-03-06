locals {
    is_windows = substr(pathexpand("~"), 0, 1) == "/" ? false : true
    is_linux   = !local.is_windows


    
}