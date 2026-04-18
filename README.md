<p align="center">
  <h1 align="center"><i><ins>Antera</ins></i></h1>
</p>

<p align="center">
  <b><i>Customizable state management<br>for Luau and the <a href=https://github.com/r-iva9/Allure>Allure Ecosystem</a></i></b>
</p>

## 📦 Installation
Install via wally:
```
Antera = "r-iva9/antera@1.0.0"
```

## 🍀 Benefits

- ***Comfortable and syntax minimal***
  > Set states via `state(val)`, get states via `state()`, connect states via `stateA(stateB)`<br>
  > Create new states from `stateA + stateB`, `stateA .. stateB` and more!

- ***Customizable***
  > Customize how your states change via `state:Setter()`<br>
  > Customize how your states give you their value via `state:Getter()`.

- ***Suited for the Allure Ecosystem***
  > Very easy to use with Allure and other modules of the ecosystem.

# ⚒️ Basic usage

Anex introduces basic Hooks and States.

## Hooks

Create a new Hook: