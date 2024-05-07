/*
**
** checker
** Checks for upgrades and inserts into the cross platform tray
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
  "os"
  "path/filepath"
  "os/exec"
  "strings"
  "sync"
  "runtime"
  "net/http"
)


var fileMutex sync.Mutex

type Appliance struct {
  Title   string `json:"title"`
  Version int    `json:"version"`
}

type UIState struct {
  Icon    string   `json:"icon"`
  Title   string   `json:"title"`
  Items   []UIItem `json:"items"`
}

type UIItem struct {
  Title string   `json:"title"`
  Exec  string   `json:"exec"`
  Icon  string   `json:"icon"`
  Items []UIItem `json:"items,omitempty"`
  Hide  bool     `json:"hide"`
}


func main() {
  exists := checkBinaryExists("podman")
  
  if !exists {
    fmt.Printf("You need to install podman to use this tool.")
  } else {
    appliances, err := getApplianceVersions()
    if err != nil {
      fmt.Printf("Error reading appliance versions: %v\n", err)
      return
    }
    uiState, err := getUIStateConfig()
    if err != nil {
      fmt.Printf("Error reading UI update config: %v\n", err)
      return
    }
    edited := checkAndUpdateContainers(appliances, &uiState)
    if edited {
      if err := saveUIStateConfig(uiState); err != nil {
        fmt.Printf("Error writing UI update config: %v\n", err)
      }
    } else {
      fmt.Println("No changes.")
    }
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

func getApplianceVersions() ([]Appliance, error) {
  var appliances []Appliance

  fileMutex.Lock()
  defer fileMutex.Unlock()

  url := "https://raw.githubusercontent.com/ipv6rslimited/cloudseeder-updates/main/versions.json"

  response, err := http.Get(url)
  if err != nil {
    return nil, err
  }
  defer response.Body.Close()

  body, err := ioutil.ReadAll(response.Body)
  if err != nil {
    return nil, err
  }

  err = json.Unmarshal(body, &appliances)
  if err != nil {
    return nil, err
  }

  return appliances, nil
}

func getUIStateConfig() (UIState, error) {
  var uiState UIState
  fileMutex.Lock()
  defer fileMutex.Unlock()
  fileContent, err := ioutil.ReadFile(filepath.Join(getConfigPath(),"ui_state.json"))
  if err != nil {
    return uiState, err
  }
  err = json.Unmarshal(fileContent, &uiState)
  return uiState, err
}

func saveUIStateConfig(uiState UIState) error {
  fileMutex.Lock()
  defer fileMutex.Unlock()
  data, err := json.MarshalIndent(uiState, "", "  ")
  if err != nil {
    return err
  }
  return ioutil.WriteFile(filepath.Join(getConfigPath(),"ui_state.json"), data, 0644)
}

func checkAndUpdateContainers(appliances []Appliance, uiState *UIState) bool {
  edited := false
  upgradeFound := false

  for i, item := range uiState.Items {
    if len(item.Items) > 0 {
      if item.Title == "IPv6rs Panel" || item.Title == "Cloud Seeder" || item.Title == "Quit" {
        continue
      }
      applianceName, err := exec.Command(getPodmanExecutable(), "exec", item.Title, "cat", "/root/.targetonce.name").CombinedOutput()
      if err != nil {
        fmt.Printf("Error retrieving appliance name for %s: %v\n", item.Title, err)
        continue
      }
      name := strings.TrimSpace(string(applianceName))

      versionOutput, err := exec.Command(getPodmanExecutable(), "exec", item.Title, "cat", "/root/.targetonce").CombinedOutput()
      if err != nil {
        fmt.Printf("Error checking container version for %s: %v\n", item.Title, err)
        continue
      }

      versionNumber := 0
      fmt.Sscanf(string(versionOutput), "%d", &versionNumber)

      for _, appliance := range appliances {
        if appliance.Title == name {
          if appliance.Version > versionNumber {
            fmt.Printf("Upgrading %s from version %d to %d\n", item.Title, versionNumber, appliance.Version)
            if !hasUpgradeOption(item.Items) {
              insertUpgradeOption(i, uiState, item, name, appliance.Version)
              edited = true
              upgradeFound = true
            }
          } else {
            fmt.Printf("%s is at the current version %d\n", item.Title, versionNumber)
            if hasUpgradeOption(item.Items) {
              removeUpgradeOption(i, uiState)
              edited = true
            }
          }
          break
        }
      }
    }
  }

  if upgradeFound {
    uiState.Icon = filepath.Join(getConfigPath(), "icons", "IconUpgrade.png")
  } else if edited {
    uiState.Icon = filepath.Join(getConfigPath(), "icons", "Icon.png")
  }

  return edited
}

func hasUpgradeOption(items []UIItem) bool {
  for _, item := range items {
    if item.Title == "Upgrade" {
      return true
    }
  }
  return false
}

func removeUpgradeOption(index int, uiState *UIState) {
  newItems := []UIItem{}
  for _, item := range uiState.Items[index].Items {
    if item.Title != "Upgrade" {
      newItems = append(newItems, item)
    }
  }
  uiState.Items[index].Items = newItems
  uiState.Items[index].Icon = "MediaPlayIcon"
}
func insertUpgradeOption(index int, uiState *UIState, item UIItem, appliance string, newVersion int) {
  var scriptPath string
  if runtime.GOOS == "windows" {
    appData := os.Getenv("LOCALAPPDATA")
    if appData == "" {
      homeDir, err := os.UserHomeDir()
      if err != nil {
        fmt.Println("Error getting home directory:", err)
        return
      }
      appData = filepath.Join(homeDir, "AppData", "Local")
    }
    scriptPath = filepath.Join(appData, "ipv6rs", "upgrade.ps1")
  } else {
    homeDir, err := os.UserHomeDir()
    if err != nil {
      fmt.Println("Error getting home directory:", err)
      return
    }
    scriptPath = filepath.Join(homeDir, ".ipv6rs", "upgrade.sh")
  }

  upgradeCommand := fmt.Sprintf("'%s' '%s' '%s' '%d'", scriptPath, item.Title, appliance, newVersion)
  terminalCommand := getShellCommand(upgradeCommand)
  upgradeItem := UIItem{
    Title: "Upgrade",
    Exec:  terminalCommand,
    Icon:  "UploadIcon",
    Hide:  true,
  }

  if index >= 0 && index < len(uiState.Items) {
    uiState.Items[index].Items = append(uiState.Items[index].Items, upgradeItem)
    uiState.Items[index].Icon = "UploadIcon"
  } else {
    fmt.Printf("Index %d out of range for UI items\n", index)
  }
}

func getShellCommand(command string) string {
  switch runtime.GOOS {
    case "windows":
      return fmt.Sprintf(`& '%s/viewer.exe' %s`, getConfigPath(), command)    
    case "darwin":
      return fmt.Sprintf(`'%s/viewer' "%s"`, getConfigPath(), command)
    case "linux":
      return fmt.Sprintf(`'%s/viewer' "%s; exec bash"`, getConfigPath(), command)
    default:
      fmt.Println("Unsupported platform")
      return ""
  }
}

func checkBinaryExists(binaryName string) bool {
  if runtime.GOOS == "windows" && filepath.Ext(binaryName) != ".exe" {
    binaryName += ".exe"
  }
  
  _, err := exec.LookPath(binaryName)
  if err != nil {
    commonPaths := []string{
      "/usr/local/bin/",
      "/usr/bin/",
      "/bin/",   
      "/usr/local/bin/",
      "/opt/homebrew/bin/",
      "/opt/podman/bin/",
      "C:\\Program Files (x86)\\Podman\\",
      "C:\\Program Files\\RedHat\\Podman\\",
    }
    for _, path := range commonPaths {
      fullPath := filepath.Join(path, binaryName)
      if _, err := os.Stat(fullPath); err == nil {
        addPath(path)
        fmt.Printf("Found '%s' at '%s'\n", binaryName, fullPath)
        return true
      }
    }
    
    return false
  } 
  return true
} 

func getPodmanExecutable() string {
  switch runtime.GOOS {
    case "windows":
      return "podman.exe"
    case "linux":
      return "podman"
    case "darwin":
      return "podman"
    default:
      fmt.Println("Unsupported")
      return ""
  }
}   

func addPath(dirs ...string) error {
  originalPath := os.Getenv("PATH")
  additionalPath := strings.Join(dirs, string(os.PathListSeparator))
  newPath := originalPath + string(os.PathListSeparator) + additionalPath
  if err := os.Setenv("PATH", newPath); err != nil {
    return err
  }  
  return nil
}

