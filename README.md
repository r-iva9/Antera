<p align="center">
  <img width="370" height="190" src="https://github.com/r-iva9/Allure/blob/main/images/logo.png?raw=true" alt="Logo">
  
  <h1 align="center"><i><a href=https://github.com/r-iva9/Allure>Allure Ecosystem</a> - <b><ins>Antera UI</ins></b></i></h1>
</p>

<div align="center">
  
  [![Docs](assets/link-docs.svg)](https://r-iva9.github.io/Allure/)
  [![Releases](assets/link-github-releases.svg)](https://github.com/r-iva9/Antera/releases)
  [![Wally](assets/link-wally.svg)](https://wally.run/package/r-iva9/antera)
</div>

<p align="center">
  <i><b>Declarative Reactive UI Framework focused on comfort</b></i> <br>
  <i>Inspired by <a href="https://github.com/dphfox/Fusion">Fusion</a> </i>
</p>

## 📦 Installation

You should have <b>Anex</b> installed <i><ins>in the same directory</ins></i> of version <i><b>1.1.0+</b></i>
```luau
Anex = "r-iva9/anex@1.1.0"
```

Install Antera via wally:
```luau
Antera = "r-iva9/antera@1.0.0"
```
or via source:
> 1. Download the `.rbxm` file asset from the latest release
> 2. Place it in your Shared packages or ReplicatedStorage/Packages

## 🍀 Goals of the project - Benefits

- ***Most of the syntax is inside tables - Comfortable and simple***
  > ```luau
  > local counter = Antera:New "TextButton" {
  >   count = Anex:State(0),
  > 
  >   Text = function(self)
  >     return "Count: " .. self.count
  >   end,
  >
  >   Antera:OnEvent "MouseButton1Click" (function(self, mounted, ...)
  >     self.count(self().count)
  >   end)
  > }
  > ```

- ***Customizable***
  > TBD

- ***Suited for the Allure Ecosystem***
  > TBD

## ⚒️ Integration

### Aery, Fusion, Maid
```luau
local myAery = Aery:Aery(Anex, Antera)
myAery:Amplify {}
```
All of Antera objects have Destroy functions for garbage collectors.
### Allure (Loader)
Antera is already a Node:
```luau
Allure:LoadNode(require("../Antera"))
```

# ⚒️ Basic usage

TBD

## Amplified Tables

TBD
