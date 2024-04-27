/* 
**
** init
** Moves files to the home directory of the current user.
**
** Distributed under the COOLER License.
**
** Copyright (c) 2024 IPv6.rs <https://ipv6.rs>
** All Rights Reserved
**
*/

package main

import (
  "runtime"
  "io"
  "fmt"
  "os"
  "os/exec"
  "path/filepath"
  "log"
)


func copyFile(src, dst string) error {
  sourceFileStat, err := os.Stat(src)
  if err != nil {
    return err
  }

  if !sourceFileStat.Mode().IsRegular() {
    return fmt.Errorf("%s is not a regular file", src)
  }

  source, err := os.Open(src)
  if err != nil {
    return err
  }
  defer source.Close()

  destination, err := os.Create(dst)
  if err != nil {
    return err
  }
  defer destination.Close()

  _, err = io.Copy(destination, source)

  return err
}

func copyDir(src string, dst string) error {
  srcInfo, err := os.Stat(src)
  if err != nil {
    return err
  }

  if err := os.MkdirAll(dst, srcInfo.Mode()); err != nil {
    return err
  }

  directory, err := os.Open(src)
  if err != nil {
    return err
  }
  defer directory.Close()

  objects, err := directory.Readdir(-1)

  for _, obj := range objects {
    srcFilePath := filepath.Join(src, obj.Name())
    dstFilePath := filepath.Join(dst, obj.Name())

    if obj.IsDir() {
      err = copyDir(srcFilePath, dstFilePath)
      if err != nil {
        log.Println(err)
      }
    } else {
      err = copyFile(srcFilePath, dstFilePath)
      if err != nil {
        log.Println(err)
      }
    }
  }
  return nil
}

func setupInitialFiles() {
  execDir, err := os.Executable()
  if err != nil {
    log.Printf("Failed to get executable path: %v", err)
  }
  execDir = filepath.Dir(filepath.Dir(execDir))
  resourcesPath := filepath.Join(execDir, "Resources")

  homeDir, err := os.UserHomeDir()
  if err != nil {
    log.Fatalf("Failed to get home dir: %v", err);
  }

  if runtime.GOOS == "linux" {
    scriptPath := filepath.Join(resourcesPath,"linux_init.sh")
    err := exec.Command("/bin/bash", scriptPath).Run()
    if err != nil {
      log.Fatalf("Failed to execute script: %v\n", err)
      return
    }
    fmt.Println("Script executed successfully.")
  }

  var configPath string
  if runtime.GOOS == "windows" {
    appData := os.Getenv("LOCALAPPDATA")
    if appData == "" {
      appData = filepath.Join(homeDir, "AppData", "Local")
    }
    configPath = filepath.Join(appData, "ipv6rs", "appliances")
  } else {
    configPath = filepath.Join(homeDir, ".ipv6rs", "appliances")
  }

  if err := os.MkdirAll(configPath, os.ModePerm); err != nil {
    log.Fatalf("Failed to create directory: %v", err)
  }

  srcConfigFile := filepath.Join(resourcesPath, "appliances.json")
  destConfigFile := filepath.Join(configPath, "..", "appliances.json")

  if err := copyFile(srcConfigFile, destConfigFile); err != nil {
    log.Fatalf("Failed to copy main init file: %v", err)
  }

  backup := "backup"
  checker := "checker"
  upgrade := "upgrade"
  if runtime.GOOS == "windows" {
    backup += ".exe"
    checker += ".exe"
    upgrade += ".ps1"
  } else {
    upgrade += ".sh"
  }

  srcBackupFile := filepath.Join(resourcesPath, backup)
  srcCheckerFile := filepath.Join(resourcesPath, checker)
  srcUpgradeFile := filepath.Join(resourcesPath, upgrade)
  destBackupFile := filepath.Join(configPath, "..", backup)
  destCheckerFile := filepath.Join(configPath, "..", checker)
  destUpgradeFile := filepath.Join(configPath, "..", upgrade)

  if err := copyFile(srcBackupFile, destBackupFile); err != nil {
    log.Fatalf("Failed to copy backup file: %v", err)
  }
  if err := copyFile(srcCheckerFile, destCheckerFile); err != nil {
    log.Fatalf("Failed to copy checker file: %v", err)
  }
  if err := copyFile(srcUpgradeFile, destUpgradeFile); err != nil {
    log.Fatalf("Failed to copy upgrade file: %v", err)
  }

  if runtime.GOOS != "windows" {
    err = os.Chmod(destBackupFile, 0755)
    if err != nil {
      log.Fatalf("Failed to chmod the backup file: %v", err)
    }
    err = os.Chmod(destCheckerFile, 0755)
    if err != nil {
      log.Fatalf("Failed to chmod the checker file: %v", err)
    }
    err = os.Chmod(destUpgradeFile, 0755)
    if err != nil {
      log.Fatalf("Failed to chmod the upgrade file: %v", err)
    }
  }

  if err := copyDir(filepath.Join(resourcesPath, "appliances"), configPath); err != nil {
    log.Fatalf("Failed to copy files: %v", err)
  }

  iconPath := filepath.Join(configPath, "..", "icons")
  if err := os.MkdirAll(iconPath, os.ModePerm); err != nil {
    log.Fatalf("Failed to create directory: %v", err)
  }


  if err := copyDir(filepath.Join(resourcesPath, "icons"), iconPath); err != nil {
    log.Fatalf("Failed to copy files: %v", err)
  }
}
