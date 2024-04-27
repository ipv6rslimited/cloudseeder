/*
**
** tray
** Provides a cross platform tray interface for Cloud Seeder by IPv6rs
**
** Distributed under the COOLER License.
**
** Copyright (c) 2024 IPv6.rs <https://ipv6.rs>
** All Rights Reserved
**
*/

package main

import (
  "path/filepath"
  "runtime"
  "bufio"
  "encoding/json"
  "fmt"
  "os"
  "os/exec"
  "sync"
  "fyne.io/fyne/v2/app"
  "sort"
  "time"
  "log"
  "github.com/ipv6rslimited/tray"
  "github.com/nightlyone/lockfile"
)


type Container struct {
  Id     string            `json:"Id"`
  Image  string            `json:"Image"`
  Names  []string          `json:"Names"`
  State  string            `json:"State"`
  Labels map[string]string `json:"Labels"`
  Exited bool              `json:"Exited"`
}

type ContainerEvent struct {
  ID         string            `json:"ID"`
  Image      string            `json:"Image"`
  Name       string            `json:"Name"`
  Status     string            `json:"Status"`
  Time       string            `json:"Time"`
  Type       string            `json:"Type"`
  Attributes map[string]string `json:"Attributes"`
}

type UIItem struct {
  Title  string            `json:"title"`
  Exec   string            `json:"exec"`
  Icon   string            `json:"icon"`
  Items  []UIItem          `json:"items,omitempty"`
  Hide   bool              `json:"hide"`
}

type UIState struct {
  Icon   string            `json:"icon"`
  Title  string            `json:"title"`
  Items  []UIItem          `json:"items"`
}

var (
  containers   map[string]Container
  containersMu sync.Mutex
)


func main() {
  lock, err := createLockFile(getConfigPath())
  if err != nil {
    fmt.Printf("Error: %v\n", err)
    os.Exit(1)
  }
  defer lock.Unlock()

  myApp := app.New()
  containers = make(map[string]Container)
  getInitialContainerState()
  go monitorContainerEvents()

  tray.Tray(myApp, filepath.Join(getConfigPath(), "ui_state.json"))

  go runPeriodicTask()

  myApp.Run()
} 

func runPeriodicTask() {
  ticker := time.NewTicker(60 * time.Minute)
  defer ticker.Stop()

  for {
    select {
      case <-ticker.C:
        runChecker()
    }
  }
}

func runChecker() {
  var cmdPath string
  if runtime.GOOS == "windows" {
    cmdPath = filepath.Join(os.Getenv("LOCALAPPDATA"), "ipv6rs", "checker.exe")
  } else {
    cmdPath = filepath.Join(os.Getenv("HOME"), ".ipv6rs", "checker")
  }

  cmd := exec.Command(cmdPath)
  tray.SetCommandNoWindow(cmd)

  err := cmd.Run()
  if err != nil {
    fmt.Printf("Failed to execute checker: %v\n", err)
  }
}

func getInitialContainerState() {
  cmd := exec.Command(getPodmanExecutable(), "ps", "--all", "--format", "json")
  output, err := cmd.Output()
  if err != nil {
    fmt.Println("Failed to get initial container states:", err)
    return
  }

  var initialContainers []Container
  if err := json.Unmarshal(output, &initialContainers); err != nil {
    fmt.Println("Failed to parse container data:", err)
    return
  }

  containersMu.Lock()
  for _, container := range initialContainers {
    if container.Labels["maintainer"] == "ipv6rs" {
      containers[container.Id] = container
    }
  }
  containersMu.Unlock()
  updateJSONFile()
}

func monitorContainerEvents() {
  cmd := exec.Command(getPodmanExecutable(), "events", "--format", "json")
  stdout, err := cmd.StdoutPipe()
  if err != nil {
    fmt.Printf("Failed to start command: %s\n", err)
    return
  }

  tray.SetCommandNoWindow(cmd)

  if err := cmd.Start(); err != nil {
    fmt.Printf("Error starting command: %s\n", err)
    return
  }

  scanner := bufio.NewScanner(stdout)
  for scanner.Scan() {
    var event ContainerEvent
    if err := json.Unmarshal([]byte(scanner.Text()), &event); err != nil {
      fmt.Println("Error decoding JSON:", err)
      continue
    }

    if event.Attributes["maintainer"] == "ipv6rs" {
      if event.Status != "init" && event.Status != "start" && event.Status != "cleanup" && event.Status != "remove" && event.Status != "died" {
        continue
      }
      containersMu.Lock()
      if existingContainer, ok := containers[event.ID]; ok {
        existingContainer.State = event.Status
        containers[event.ID] = existingContainer
      } else {
        containers[event.ID] = Container{
          Id:     event.ID,
          Image:  event.Image,
          Names:  []string{event.Name},
          State:  event.Status,
          Labels: event.Attributes,
        }
      }
      containersMu.Unlock()
      updateJSONFile()
    }
  }
  if err := cmd.Wait(); err != nil {
    fmt.Printf("Command finished with error: %s\n", err)
  }
}

func getExecPath() string {
  execDir, err := os.Executable()
  if err != nil {
    log.Printf("Failed to get executable path: %v", err)
  }
  execDir = filepath.Dir(execDir)
  return execDir
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

func getResourcesPath() string {
  execDir, err := os.Executable() 
  if err != nil {
    log.Printf("Failed to get executable path: %v", err)
  }
  execDir = filepath.Dir(filepath.Dir(execDir))
  resourcesPath := filepath.Join(execDir, "Resources")
  return resourcesPath
}

func updateJSONFile() {
  currentUIState, err := loadUIState()
  if err != nil {
    fmt.Println("Error loading current UI state:", err)
    return
  }

  var hasUpgrade bool
  uiState := UIState{
    Icon:  filepath.Join(getConfigPath(), "icons", "Icon.png"),
    Title: "Cloud Seeder Monitor",
    Items: []UIItem{},
  }

  containersMu.Lock()
  defer containersMu.Unlock()

  var containerUIItems []UIItem

  for _, container := range containers {
    if container.State == "remove" {
      continue
    }

    var controlItems []UIItem
    var icon string

    switch container.State {
      case "running", "start":
        icon = "MediaPlayIcon"
        controlItems = append(controlItems, UIItem{
          Title: "Stop",
          Exec:  getPodmanExecutable() + " stop " + container.Names[0],
          Icon:  "MediaStopIcon",
          Hide:  true,
        })
        controlItems = append(controlItems, createShellCommandItem(container.Names[0]))

      case "died", "exited", "cleanup":
        icon = "MediaStopIcon"
        controlItems = append(controlItems, UIItem{
          Title: "Start",
          Exec:  getPodmanExecutable() + " start " + container.Names[0],
          Icon:  "MediaPlayIcon",
          Hide:  true,
        })
    }

    upgradeItem := findExistingUpgradeItem(currentUIState, container.Names[0])
    if upgradeItem != nil {
      controlItems = append(controlItems, *upgradeItem)
      hasUpgrade = true
      icon = "UploadIcon"
    }

    containerUIItems = append(containerUIItems, UIItem{
      Title: container.Names[0],
      Icon:  icon,
      Items: controlItems,
    })
  }

  sort.Slice(containerUIItems, func(i, j int) bool {
    return containerUIItems[i].Title < containerUIItems[j].Title
  })

  url := "https://ipv6.rs/panel"
  var openCommand string
  var cloudseeder string

  switch runtime.GOOS {
    case "windows":
      openCommand = fmt.Sprintf("Start-Process '%s'", url)
      cloudseeder = "cloudseeder.exe"
    case "darwin":
      openCommand = fmt.Sprintf("open %s", url)
      cloudseeder = "cloudseeder"
    case "linux":
      openCommand = fmt.Sprintf("xdg-open %s", url)
      cloudseeder = "cloudseeder"
    default:
      openCommand = "echo 'Unsupported platform'"
  }
  uiState.Items = append(uiState.Items, UIItem{
    Title: "IPv6rs Panel",
    Exec:  openCommand,
    Icon:  "AccountIcon",
    Hide: true,
  })

  if runtime.GOOS == "windows" {
    uiState.Items = append(uiState.Items, UIItem{
      Title: "Cloud Seeder",
      Exec: "Start-Process '" + filepath.Join(getExecPath(),cloudseeder) + "'",
      Icon: "HomeIcon",
      Hide: true,
    })
  } else {
    uiState.Items = append(uiState.Items, UIItem{
      Title: "Cloud Seeder",
      Exec: "'" + filepath.Join(getExecPath(),cloudseeder) + "'",
      Icon: "HomeIcon",
      Hide: true,
    })
  }

  uiState.Items = append(uiState.Items, containerUIItems...)
  uiState.Items = append(uiState.Items, UIItem{
    Title: "Quit",
    Exec:  "EXIT",
    Icon:  "",
  })
  if hasUpgrade {
    uiState.Icon = filepath.Join(getConfigPath(), "icons", "IconUpgrade.png")
  }

  file, err := json.MarshalIndent(uiState, "", "  ")
  if err != nil {
    fmt.Println("Error marshalling JSON:", err)
    return
  }

  if err := os.WriteFile(filepath.Join(getConfigPath(), "ui_state.json"), file, 0644); err != nil {
    fmt.Println("Error writing JSON file:", err)
  }
}

func findExistingUpgradeItem(state UIState, containerName string) *UIItem {
  for _, item := range state.Items {
    if item.Title == containerName {
      for _, subItem := range item.Items {
        if subItem.Title == "Upgrade" {
          return &subItem
        }
      }
    }
  }
  return nil
}

func loadUIState() (UIState, error) {
  var state UIState
  configFile := filepath.Join(getConfigPath(), "ui_state.json")

  if _, err := os.Stat(configFile); os.IsNotExist(err) {
    return createDefaultUIState(), nil
  }

  file, err := os.ReadFile(configFile)
  if err != nil {
    return createDefaultUIState(), nil
  }
  if err = json.Unmarshal(file, &state); err != nil {
    return createDefaultUIState(), nil
  }

  return state, nil
}

func createDefaultUIState() UIState {
  state := UIState{
    Icon:  filepath.Join(getResourcesPath(), "Icon.png"),
    Title: "Cloud Seeder Monitor",
    Items: []UIItem{},
  }
  return state
}

func createShellCommandItem(containerName string) UIItem {
  return UIItem{
    Title: "Shell",
    Exec:  getShellCommand(containerName),
    Icon:  "ComputerIcon",
  }
}

func getShellCommand(containerName string) string {
  switch runtime.GOOS {
    case "windows":
      return fmt.Sprintf("Start-Process powershell -ArgumentList '-NoExit', '-Command', '%s'", fmt.Sprintf("podman exec -it %s /bin/bash", containerName))
    case "darwin":
      return fmt.Sprintf("osascript -e 'tell application \"Terminal\" to do script \"podman exec -it %s /bin/bash\"'", containerName)
    case "linux":
      return fmt.Sprintf("gnome-terminal -- bash -c 'podman exec -it %s /bin/bash; exec bash'", containerName)
    default:
      fmt.Println("Unsupported platform")
      return ""
  }
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

func createLockFile(configPath string) (lockfile.Lockfile, error) {
  var lock lockfile.Lockfile
  lockFilePath := filepath.Join(configPath, "tray.lock")
  var err error
  lock, err = lockfile.New(lockFilePath)
  if err != nil {
    return lock, fmt.Errorf("failed to create lock file: %v", err)
  }

  err = lock.TryLock()
  if err != nil {
    return lock, fmt.Errorf("failed to acquire lock: %v", err)
  }
  return lock, nil
}
