/* 
**
** main
** Provides a launcher interface for Cloud Seeder by IPv6rs
**
** Distributed under the COOLER License.
**
** Copyright (c) 2024 IPv6.rs <https://ipv6.rs>
** All Rights Reserved
**
*/

package main

import (
  "github.com/ipv6rslimited/configurator"
  "strings"
  "encoding/json"
  "fyne.io/fyne/v2"
  "fyne.io/fyne/v2/app"
  "fyne.io/fyne/v2/canvas"
  "fyne.io/fyne/v2/container"
  "fyne.io/fyne/v2/driver/desktop"
  "fyne.io/fyne/v2/layout"
  "fyne.io/fyne/v2/theme"
  "fyne.io/fyne/v2/widget"
  "path/filepath"
  "io/ioutil"
  "log"
  "os"
  "os/exec"
  "runtime"
  "fmt"
  "github.com/nightlyone/lockfile"
)

type ApplianceInfo struct {
  Title        string `json:"title"`
  Short        string `json:"short"`
  Description  string `json:"description"`
  Requirements string `json:"requirements"`
  Action       string `json:"action"`
}

var (
  applianceInfos []ApplianceInfo
)


func main() {
  myApp := app.New()
  exists := checkBinaryExists("podman")
  myApp.Settings().SetTheme(theme.LightTheme())

  if !exists {
    createDialogWindow(myApp, "You must install podman to use Cloud Seeder by IPv6rs","OK")
  } else {
    var splashWindow fyne.Window
    if deskDriver, ok := myApp.Driver().(desktop.Driver); ok {
      splashWindow = deskDriver.CreateSplashWindow()
    } else {
      splashWindow = myApp.NewWindow("Cloud Seeder by IPv6rs")
    }

    var err error

    homeDir, err := os.UserHomeDir()
    if err != nil {
      log.Fatalf("Failed to get user home directory: %v", err)
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

    err = os.MkdirAll(configPath, os.ModePerm)
    if err != nil {
      fmt.Printf("Error creating directory: %v\n", err)
      os.Exit(1)
    }

    lock, err := createLockFile(configPath)
    if err != nil {
      fmt.Printf("Error: %v\n", err)
      os.Exit(1)
    }
    defer lock.Unlock()


    execDir, err := os.Executable()
    if err != nil {
      log.Printf("Failed to get executable path: %v", err)
    }
    trayPath := filepath.Join(filepath.Dir(execDir), "cloudseeder-monitor")
    if runtime.GOOS == "windows" {
      trayPath += ".exe"
    }
    execDir = filepath.Dir(filepath.Dir(execDir))
    resourcesPath := filepath.Join(execDir, "Resources")

    myWindow := myApp.NewWindow("Cloud Seeder by IPv6rs")
    myWindow.Resize(fyne.NewSize(800, 600))

    go func() {
      statusLabel := widget.NewLabel("Initializing Appliances...")
      image := canvas.NewImageFromFile(filepath.Join(resourcesPath, "ipv6rs.png"))
      image.FillMode = canvas.ImageFillOriginal

      splashWindow.SetContent(container.NewVBox(
        image,
        container.NewHBox(
          layout.NewSpacer(),
          statusLabel,
          layout.NewSpacer(),
      )))
      splashWindow.Show()
 
      setupInitialFiles()
      statusLabel.SetText("Loading Appliances...")
      applianceInfos, err = loadAppliancesFromJSON(filepath.Join(configPath, "appliances.json"))

      if err != nil {
        log.Fatal(err)
      }
      updateUI(myApp, myWindow, configPath)

      splashWindow.Close()
      myWindow.Show()
    }()

    myWindow.SetCloseIntercept(func() {
      myApp.Quit()
    })

    go func() {
      cmd := exec.Command(trayPath)
      setSysProcAttr(cmd)
      setCommandNoWindow(cmd)

      err := cmd.Start()
      if err != nil {
        fmt.Println("Error starting tray application:", err)
        return
      }

      go func() {
        err = cmd.Wait()
        if err != nil {
          fmt.Println("Tray application exited with error:", err)
        } else {
          fmt.Println("Tray application exited successfully")
        }
      }()
    }()

    myApp.Run()
  }
}

func updateUI(app fyne.App, window fyne.Window, configPath string) {
  cards := make([]fyne.CanvasObject, 0)

  for _, info := range applianceInfos {
    card := createApplianceCard(app, window, info, configPath)
    cards = append(cards, card)
  }

  cardSize := fyne.NewSize(250, 320)
  applianceGrid := container.NewGridWrap(cardSize, cards...)
  scrollContainer := container.NewScroll(applianceGrid)

  window.SetContent(scrollContainer)
}

func createApplianceCard(app fyne.App, window fyne.Window, info ApplianceInfo, configPath string) *fyne.Container {
  image := canvas.NewImageFromFile(filepath.Join(configPath, "appliances", info.Short, "image.png"))
  image.FillMode = canvas.ImageFillContain
  image.SetMinSize(fyne.NewSize(240, 100))

  titleLabel := widget.NewLabelWithStyle(info.Title, fyne.TextAlignCenter, fyne.TextStyle{Bold: true})
  titleLabel.Wrapping = fyne.TextWrapWord

  descriptionLabel := widget.NewLabelWithStyle(info.Description, fyne.TextAlignCenter, fyne.TextStyle{})
  descriptionLabel.Wrapping = fyne.TextWrapWord

  content := container.NewVBox(image, titleLabel, descriptionLabel)
  card := widget.NewCard("", "", content)

  return makeCardInteractive(app, window, card, info.Action, info.Requirements)
}


func loadAppliancesFromJSON(filePath string) ([]ApplianceInfo, error) {
  file, err := ioutil.ReadFile(filePath)
  if err != nil {
    return nil, err
  }
  var appliances []ApplianceInfo
  err = json.Unmarshal(file, &appliances)
  if err != nil {
    return nil, err
  }
  return appliances, nil
}

func makeCardInteractive(app fyne.App, window fyne.Window, card *widget.Card, action string, requirements string) *fyne.Container {
  tap := func() {
    createConfirmationWindow(app, requirements, action)
  }
  button := widget.NewButton("", func() {
    tap()
  })
  button.Importance = widget.LowImportance
  button.ExtendBaseWidget(button)
  cardContainer := container.NewMax(button, card)

  return cardContainer
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

func createConfirmationWindow(app fyne.App, requirements string, target string) {
  win := app.NewWindow("Confirmation")
  win.Resize(fyne.NewSize(600, 300))

  requirementsLabel := widget.NewLabel(requirements)
  requirementsLabel.Wrapping = fyne.TextWrapWord
  requirementsLabel.TextStyle.Monospace = true

  continueBtn := widget.NewButton("Continue", func() {
    configurator.NewWindow(app, target, "IPv6rs", "https://ipv6.rs")
    win.Close()
  })

  cancelBtn := widget.NewButton("Cancel", func() {
    win.Close()
  })

  content := container.NewVBox(
    requirementsLabel,
    layout.NewSpacer(),
    container.NewHBox(layout.NewSpacer(), cancelBtn, continueBtn),
  )

  paddingSize := fyne.NewSize(50, 50)
  paddedContainer := container.New(configurator.NewResizablePaddedLayout(paddingSize), content)

  win.SetContent(paddedContainer)
  win.Show()
}

func createDialogWindow(app fyne.App, message string, btnLabel string) {
  win := app.NewWindow("Dialog")
  win.Resize(fyne.NewSize(600, 300))

  messageLabel := widget.NewLabel(message)
  messageLabel.Wrapping = fyne.TextWrapWord
  messageLabel.TextStyle.Monospace = true

  btn := widget.NewButton(btnLabel, func() {
    win.Close()
    os.Exit(0);
  })

  content := container.NewVBox(
    messageLabel,
    layout.NewSpacer(),
    container.NewHBox(layout.NewSpacer(), btn),
  )

  paddingSize := fyne.NewSize(50, 50)
  paddedContainer := container.New(configurator.NewResizablePaddedLayout(paddingSize), content)

  win.SetContent(paddedContainer)
  win.ShowAndRun()
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

func createLockFile(configPath string) (lockfile.Lockfile, error) {
  var lock lockfile.Lockfile
  lockFilePath := filepath.Join(configPath, "cloudseeder.lock")
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


