// +build !windows

/*
**
** sysproc_others
** Creates a new process group for a process to detach from parent
** 
** Distributed under the COOLER License.
** 
** Copyright (c) 2024 IPv6.rs <https://ipv6.rs>
** All Rights Reserved
** 
*/
package main


import (
  "os/exec"
  "syscall"
)


func setSysProcAttr(cmd *exec.Cmd) {
  cmd.SysProcAttr = &syscall.SysProcAttr{
    Setpgid: true,
  }
}

func setCommandNoWindow(cmd *exec.Cmd) {
}
