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
  "encoding/json"
  "io"
  "fmt"
  "os"
  "os/exec"
  "archive/tar"
  "compress/gzip"
  "net/http"
  "path/filepath"
  "log"
)

type Appliance struct {
  Title        string `json:"title"`
  Short        string `json:"short"`
  Version      int    `json:"version"`
  Description  string `json:"description"`
  Requirements string `json:"requirements"`
  Action       string `json:"action"`
}

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
    configPath = filepath.Join(appData, "ipv6rs")
  } else {
    configPath = filepath.Join(homeDir, ".ipv6rs")
  }
  appliancePath := filepath.Join(configPath, "appliances")

  if err := os.MkdirAll(appliancePath, os.ModePerm); err != nil {
    log.Fatalf("Failed to create directory: %v", err)
  }

  url := "https://raw.githubusercontent.com/ipv6rslimited/cloudseeder-appliances/main/appliances.json"

  applianceConfig, err := downloadFile(url)
  if err != nil {
    log.Fatalf("Unable to get the main appliance config: %v", err)
  }
  defer applianceConfig.Close()

  buffer, err := io.ReadAll(applianceConfig)
  if err != nil {
    log.Fatalf("Unable to read the main appliance config: %v", err)
  }

  if err := saveDownloadedFile(buffer, filepath.Join(configPath, "appliances.json")); err != nil {
    log.Fatalf("Unable to save the main appliance config: %v", err)
  }

  appliances, err := parseApplianceConfig(buffer)
  if err != nil {
    log.Fatalf("Unable to parse the main appliance config: %v", err)
  }

  if err := downloadAppliances(appliances, appliancePath); err != nil {
    log.Fatalf("Failed to download appliances: %v", err)
  }

  sideloadedApps, err := loadJSONFile(filepath.Join(configPath, "sideload.json"))
  if err == nil {
    appliances = mergeAppliances(appliances, sideloadedApps)
    if err := saveAppliances(appliances, filepath.Join(configPath, "appliances.json")); err != nil {
      log.Fatalf("Failed to save merged appliances: %v", err)
    }
  } else {
    log.Println("No sideload.json found or error reading: ", err)
  }

  viewer := "viewer"
  backup := "backup"
  checker := "checker"
  upgrade := "upgrade"
  if runtime.GOOS == "windows" {
    backup += ".exe"
    checker += ".exe"
    upgrade += ".ps1"
    viewer += ".exe"
  } else {
    upgrade += ".sh"
  }

  srcViewerFile := filepath.Join(resourcesPath, viewer)
  srcBackupFile := filepath.Join(resourcesPath, backup)
  srcCheckerFile := filepath.Join(resourcesPath, checker)
  srcUpgradeFile := filepath.Join(resourcesPath, upgrade)
  destViewerFile := filepath.Join(configPath, viewer)
  destBackupFile := filepath.Join(configPath, backup)
  destCheckerFile := filepath.Join(configPath, checker)
  destUpgradeFile := filepath.Join(configPath, upgrade)

  if err := copyFile(srcViewerFile, destViewerFile); err != nil {
    log.Fatalf("Failed to copy viewer file: %v", err)
  }
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
    err = os.Chmod(destViewerFile, 0755)
    if err != nil {
      log.Fatalf("Failed to chmod the viewer file: %v", err)
    }
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

  iconPath := filepath.Join(configPath, "icons")
  if err := os.MkdirAll(iconPath, os.ModePerm); err != nil {
    log.Fatalf("Failed to create directory: %v", err)
  }
  if err := copyDir(filepath.Join(resourcesPath, "icons"), iconPath); err != nil {
    log.Fatalf("Failed to copy files: %v", err)
  }
}

func downloadFile(url string) (io.ReadCloser, error) {
  response, err := http.Get(url)
  if err != nil {
    return nil, fmt.Errorf("failed to download file: %w", err)
  }

  if response.StatusCode != 200 {
    response.Body.Close()
    return nil, fmt.Errorf("received non-200 status code: %d", response.StatusCode)
  }

  return response.Body, nil
}

func saveDownloadedFile(data []byte, dst string) error {
  out, err := os.Create(dst)
  if err != nil {
    return fmt.Errorf("failed to create file: %w", err)
  }
  defer out.Close()

  _, err = out.Write(data)
  if err != nil {
    return fmt.Errorf("failed to save file: %w", err)
  }
  return nil
}

func parseApplianceConfig(data []byte) ([]Appliance, error) {
  var appliances []Appliance
  if err := json.Unmarshal(data, &appliances); err != nil {
    return nil, fmt.Errorf("failed to decode JSON: %w", err)
  }
  return appliances, nil
}

func downloadAppliances(appliances []Appliance, baseDir string) error {
  baseURL := "https://raw.githubusercontent.com/ipv6rslimited/cloudseeder-appliances/main/"
  for _, app := range appliances {
    fmt.Printf("Downloading and installing %s...\n", app.Title)
    fileURL := baseURL + app.Short + ".cloudseeder"
    tempFile := filepath.Join(os.TempDir(), app.Short+".tgz")

    fileData, err := downloadFile(fileURL)
    if err != nil {
      log.Fatalf("Error downloading %s: %v\n", app.Title, err)
    }

    buffer, err := io.ReadAll(fileData)
    if err != nil {
      log.Fatalf("Error reading %s: %v\n", app.Title, err)
    }
    fileData.Close()

    if err := saveDownloadedFile(buffer, tempFile); err != nil {
      log.Fatalf("Error saving %s: %v\n", app.Title, err)
      continue
    }

    extractPath := filepath.Join(baseDir)
    if err := untarGz(tempFile, extractPath); err != nil {
      log.Fatalf("Error extracting %s: %v\n", app.Title, err)
      continue
    }
    fmt.Printf("%s downloaded and installed.\n", app.Title)
  }
  return nil
}

func untarGz(src, dst string) error {
  file, err := os.Open(src)
  if err != nil {
    return err
  }
  defer file.Close()

  gzr, err := gzip.NewReader(file)
  if err != nil {
    return err
  }
  defer gzr.Close()

  tr := tar.NewReader(gzr)

  for {
    header, err := tr.Next()
    switch {
      case err == io.EOF:
        return nil
      case err != nil:
        return err
      case header == nil:
        continue
    }
    target := filepath.Join(dst, header.Name)
    switch header.Typeflag {
      case tar.TypeDir:
        if err := os.MkdirAll(target, 0755); err != nil {
	  return err
        }
      case tar.TypeReg:
        outFile, err := os.Create(target)
        if err != nil {
          return err
        }
        if _, err := io.Copy(outFile, tr); err != nil {
          outFile.Close()
          return err
        }
        outFile.Close()
    }
  }
}

func loadJSONFile(filePath string) ([]Appliance, error) {
  var appliances []Appliance
  file, err := os.Open(filePath)
  if err != nil {
    return nil, err
  }
  defer file.Close()

  if err := json.NewDecoder(file).Decode(&appliances); err != nil {
    return nil, err
  }
  return appliances, nil
}

func mergeAppliances(main, sideload []Appliance) []Appliance {
  existing := make(map[string]int)
  for index, app := range main {
    existing[app.Short] = index
  }
  for _, app := range sideload {
    if index, found := existing[app.Short]; found {
      main[index] = app
    } else {
      main = append(main, app)
    }
  }
  return main
}

func saveAppliances(appliances []Appliance, filePath string) error {
  file, err := os.Create(filePath)
  if err != nil {
    return err
  }
  defer file.Close()
  encoder := json.NewEncoder(file)
  encoder.SetIndent("", "  ")
  return encoder.Encode(appliances)
}
