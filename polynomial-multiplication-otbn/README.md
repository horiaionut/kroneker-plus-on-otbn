# Kroneker+ Polynomial Multiplication

## Introduction

## Usage

## OTBN setup

* Download the latest version of *opentitan* from [here](https://github.com/lowRISC/opentitan/tree/master).
* Download this repository and place the ```polynomial-mul``` folder directly under ```opentitan```.
* Download and start the opentitan docker container following [this](https://github.com/lowRISC/opentitan/blob/master/util/container/README.md) guide.

### Change OTBN IMEM and DMEM sizes

In ```hw/ip/otbn/data/otbn.hjson``` change the current sizes of DMEM and IMEM into:

```
{ window: {
        name: "IMEM",
        items: "4096",
        ...
```

```
{ skipto: "0x9000" }

// Dmem size (given as `items` below) must be a power of two.
    { window: {
        name: "DMEM",
        items: "2000",
        ...
```

## Input

Change the ```input_polynomial1```, ```input_polynomial2``` values in the data memory part of the kroneker+ source file (ex. the file ```polynomial-mul/kroneker+/l=64,t=8/kroneker+```) to your polynomial coefficients. Each coefficient is regarded as one 32-bit word, the coefficient of Xˆ0 being first (upmost).

### Build & Run

For the l=64, t=8 version run:

```
./polynomial-mul/scripts/build.sh kroneker+/l=64,t=8/kroneker+
```
