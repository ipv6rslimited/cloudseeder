/*
**
** backup
** Provides a cross platform backup function for Cloud Seeder by IPv6rs Appliances
**
** Distributed under the COOLER License.
**
** Copyright (c) 2024 IPv6.rs <https://ipv6.rs>
** All Rights Reserved
**
*/

package main

import (
  "encoding/json"
  "fmt"
  "io/ioutil"
  "log"
  "os"
  "os/exec"
  "path/filepath"
  "runtime"
  "sort"
  "strings"
  "time"
)


func main() {
  if len(os.Args) < 3 {
    log.Fatalf("Usage: %s [backup|restore] containerName [timestamp]", os.Args[0])
  }
  operation := os.Args[1]
  containerName := os.Args[2]

  configDir := getConfigPath()
  backupDir := filepath.Join(configDir, "backups")
  os.MkdirAll(backupDir, os.ModePerm)

  switch operation {
    case "backup":
      if err := stopContainer(containerName); err != nil {
        log.Fatalf("Error stopping container: %v", err)
      }

      imageName, err := commitContainer(containerName)
      if err != nil {
        log.Fatalf("Error committing container: %v", err)
      }

      imageFilePath := filepath.Join(backupDir, imageName+".tar")
      configFilePath := filepath.Join(backupDir, imageName+".config")
      if err := saveImage(imageName, imageFilePath); err != nil {
        log.Fatalf("Error saving image to file: %v", err)
      }
      if err := saveContainerConfig(containerName, configFilePath); err != nil {
          log.Fatalf("Error saving container configuration: %v", err)
      }

      fmt.Printf("Backup completed.")
    case "restore":
      var selectedTimestamp string
      if len(os.Args) > 3 {
        selectedTimestamp = os.Args[3]
      }
      imageFilePath, configFilePath, err := findBackupFiles(backupDir, containerName, selectedTimestamp)
      if err != nil {
        log.Fatalf("Error finding backup files: %v", err)
      }

        if err := restoreContainer(containerName, imageFilePath, configFilePath); err != nil {
            log.Fatalf("Error restoring container: %v", err)
        }

        fmt.Println("Restore completed successfully.")

    default:
        log.Fatalf("Invalid operation: %s. Use 'backup' or 'restore'.", operation)
  }
}

func getConfigPath() string {
  var configPath string
  homeDir, err := os.UserHomeDir()
  if err != nil {
    fmt.Println("Failed to get home directory:", err)
    os.Exit(1)
  }
  if runtime.GOOS == "windows" {
    appData := os.Getenv("LOCALAPPDATA")
    if appData == "" {
      appData = filepath.Join(homeDir, "AppData", "Local")
    }
    configPath = filepath.Join(appData, "ipv6rs")
  } else {
    configPath = filepath.Join(homeDir, ".ipv6rs")
  }
  return configPath
}
      
func isContainerRunning(containerName string) (bool, error) {
  cmd := exec.Command(getPodmanExecutable(), "inspect", "--format", "{{.State.Running}}", containerName)
  output, err := cmd.Output()
  if err != nil {
    return false, err
  }
  return strings.TrimSpace(string(output)) == "true", nil
}

func stopContainer(containerName string) error {
  running, err := isContainerRunning(containerName)
  if err != nil {
    return err
  }
  if running {
    cmd := exec.Command(getPodmanExecutable(), "stop", containerName)
    if err := cmd.Run(); err != nil {
      return err
    }
    fmt.Println("Container stopped:", containerName)
  }
  return nil
}

func commitContainer(containerName string) (string, error) {
  timestamp := time.Now().UnixMilli()
  newImageName := fmt.Sprintf("%s-%d", strings.TrimSpace(containerName), timestamp)

  cmd := exec.Command(getPodmanExecutable(), "commit", containerName, newImageName)
  if err := cmd.Run(); err != nil {
    return "", err
  }
  fmt.Println("Container committed to image:", newImageName)
  return newImageName, nil
}

func saveImage(imageName, filePath string) error {
  cmd := exec.Command(getPodmanExecutable(), "save", "-o", filePath, imageName)
  if err := cmd.Run(); err != nil {
    return err
  }
  fmt.Println("Image saved to file:", filePath)
  return nil
}

func saveContainerConfig(containerName, configPath string) error {
  cmd := exec.Command(getPodmanExecutable(), "inspect", containerName)
  output, err := cmd.Output()
  if err != nil {
    return err
  }
  if err := ioutil.WriteFile(configPath, output, 0644); err != nil {
      return err
  }
  fmt.Println("Container configuration saved to:", configPath)
  return nil
}

func findBackupFiles(backupDir, containerName, timestamp string) (string, string, error) {
  files, err := ioutil.ReadDir(backupDir)
  if err != nil {
    return "", "", err
  }
    
  var matchedFiles []string
  for _, file := range files {
    if strings.HasPrefix(file.Name(), containerName) && (timestamp == "" || strings.Contains(file.Name(), timestamp)) {
      baseName := strings.TrimSuffix(file.Name(), ".tar")
      baseName = strings.TrimSuffix(baseName, ".config")
      matchedFiles = append(matchedFiles, baseName)
    }
  }
       
  if len(matchedFiles) == 0 {
    return "", "", fmt.Errorf("no backup files found for container %s", containerName)
  }
        
  sort.Strings(matchedFiles)
  latestFile := matchedFiles[len(matchedFiles)-1]
  return filepath.Join(backupDir, latestFile+".tar"), filepath.Join(backupDir, latestFile+".config"), nil
}

func loadImage(filePath string) error {
  cmd := exec.Command(getPodmanExecutable(), "load", "-i", filePath)
  output, err := cmd.CombinedOutput()
  if err != nil {
    fmt.Printf("Error loading image: %s\nOutput: %s\n", err, output)
    return err
  }
  fmt.Println("Image loaded from file:", filePath)
  return nil
}

func removeContainer(containerName string) error {
  cmd := exec.Command(getPodmanExecutable(), "rm", "-f", containerName)
  if err := cmd.Run(); err != nil {
    return err
  }
  fmt.Println("Container removed:", containerName)
  return nil
}

func quoteArgument(arg string) string {
  return "\"" + strings.ReplaceAll(arg, "\"", "\\\"") + "\""
}

func getImageNameFromFileName(fileName string) string {
  baseName := strings.TrimSuffix(fileName, ".tar")
  return "localhost/" + baseName + ":latest"
}

func recreateContainerFromConfig(containerName string, imageFilePath string, configPath string) error {
  imageName := getImageNameFromFileName(filepath.Base(imageFilePath))

  data, err := ioutil.ReadFile(configPath)
  if err != nil {
    return err
  }

  var configs []map[string]interface{}
  if err := json.Unmarshal(data, &configs); err != nil {
    return err
  }

  if len(configs) == 0 {
    return fmt.Errorf("no configuration data found")
  }

  config := configs[0]["Config"].(map[string]interface{})
  hostConfig := configs[0]["HostConfig"].(map[string]interface{})

  envVars := config["Env"].([]interface{})
  var envs []string
  for _, e := range envVars {
    env := e.(string)
    if !strings.HasPrefix(env, "container_uuid=") && !strings.HasPrefix(env, "HOSTNAME=") {
      envs = append(envs, "--env="+quoteArgument(env))
    }
  }

  var volumes []string
  for _, v := range hostConfig["Binds"].([]interface{}) {
    volume := v.(string)
    if strings.Contains(volume, "cgroup") {
        volume = "cgroup:/sys/fs/cgroup:ro"
    }
    volumes = append(volumes, "--volume="+quoteArgument(volume))
  }

  caps := hostConfig["CapAdd"].([]interface{})
  var capabilities []string
  for _, cap := range caps {
    capabilities = append(capabilities, "--cap-add="+quoteArgument(cap.(string)))
  }

  devices := hostConfig["Devices"].([]interface{})
  var deviceMappings []string
  for _, d := range devices {
    dev := d.(map[string]interface{})
    deviceMappings = append(deviceMappings, "--device="+quoteArgument(dev["PathOnHost"].(string)))
  }

  var securityOpts []string
  for _, so := range hostConfig["SecurityOpt"].([]interface{}) {
    securityOpts = append(securityOpts, "--security-opt="+quoteArgument(so.(string)))
  }

  privileged := hostConfig["Privileged"].(bool)
  var privFlag string
  if privileged {
    privFlag = "--privileged"
  }

  args := []string{"run", "-d", "--name", quoteArgument(containerName), privFlag}
  args = append(args, envs...)
  args = append(args, volumes...)
  args = append(args, capabilities...)
  args = append(args, deviceMappings...)
  args = append(args, securityOpts...)
  args = append(args, quoteArgument(imageName))

  podmanCommand := strings.Join(args, " ")
  podmanCommand = "podman " + podmanCommand

  var cmd *exec.Cmd

  switch runtime.GOOS {
    case "windows":
      cmd = exec.Command("powershell", "-NoExit", "-Command", podmanCommand)
    case "darwin":
      cmd = exec.Command("bash", "-c", podmanCommand)
    case "linux":
      cmd = exec.Command("bash", "-c", podmanCommand)
    default:
      return fmt.Errorf("unsupported platform")
  }

  fmt.Println("Executing command:", cmd.String())

  if output, err := cmd.CombinedOutput(); err != nil {
    fmt.Printf("Error executing command: %s\nOutput: %s\n", err, output)
    return err
  }

  fmt.Println("Container recreated with full config")
  return nil
}

func restoreContainer(containerName, imageFilePath, configFilePath string) error {
  if err := removeContainer(containerName); err != nil {
    return err
  }

  if err := loadImage(imageFilePath); err != nil {
    return err
  }
  return recreateContainerFromConfig(containerName, imageFilePath, configFilePath)
}

func getPodmanExecutable() string {
  switch runtime.GOOS {
    case "windows":
      return "podman.exe"
    case "linux":
      return "podman"
    case "darwin":
      return "/opt/podman/bin/podman"
    default:
      fmt.Println("Unsupported")
      return ""
  }
}
  

