---
id: operating-systems-introduction-to-operating-systems
title: Introduction To Operating Systems
course: operating-systems
lecture: introduction-to-operating-systems
---

# Introduction To Operating Systems

**OSTEP chapter**: [2. Introduction to Operating Systems](https://pages.cs.wisc.edu/~remzi/OSTEP/intro.pdf)

## What is an operating system?
Let's first look at the hardware of a computing system. This computing system consists of:

* Central Processing Unit (CPU)
* Physical Memory
* Network Interfaces (Ethernet/Wifi Card)
* GPU
* Storage Devices (Disk, Flash drives [USB])

In addition, a computing system can have higher level applications. These are the "programs" that we use every day on our computer:

* Skype
* Word
* Chrome

All of these hardware components get used by multiple applications at once. A single CPU consists of multiple cores, so even one CPU has more than one processing element to hand out. A server machine may run a web server, a database and a computation intensive simulation at the same time. Even on hardware that traditionally ran a single application, this holds: on your phone you have a browser, Skype, Facebook, and the one application that makes and receives phone calls.

**The Operating System is the layer of software that sits between the hardware components and the higher level applications.**

## Main Functions of an Operating System
An operating system **abstracts** and **arbitrates** the use of the computer system.

* **Abstraction** simplifies what the hardware looks like to the software above it.
* **Arbitration** manages and distributes the hardware among the applications competing for it.

#### Operating systems hide hardware complexity.
You don't want to have to worry about the nuts and bolts of interacting with storage devices when you are writing an application. The operating system provides a higher level abstraction, the *file*, with a number of operations - like *read* and *write* - which applications can interact with.

The same goes for the network. A web server accepting and responding to end user requests shouldn't have to think about the bits and packets it needs to compose. The operating system abstracts the networking resource as a *socket*, and provides operations to *send* and *receive* data over it.

<details>
<summary>Abstraction or arbitration quiz spoiler</summary>

Supporting different types of speakers is another abstraction the operating system provides. You can plug in one set of speakers and, if they don't work, exchange them for something else. In some cases drivers are required to make this work. The device driver knows the details of the particular hardware element, like that one set of speakers. That is what lets the operating system control the device without knowing those details itself.
</details>

#### Operating systems manage underlying hardware resources.
Operating system allocates memory for applications, schedules them for execution on the CPU, controls access to various network devices and so on.

<details>
<summary>Operating system components quiz spoiler</summary>

Cache memory is a tricky case. Both the operating system and the application software use the cache for performance, but the OS does not directly manage it: the hardware decides what to keep and what to evict. The OS does control whether a mapping is cacheable, and it issues explicit flush operations where correctness demands them, but there is no OS component whose job is managing the cache.
</details>

#### Provides isolation and protection.
When multiple applications are co-running on the same hardware, the operating system has to ensure that each of them can make adequate progress and that they don't hurt one another. It allocates different parts of the physical memory to different applications, and it makes sure that - unless explicitly intended - applications don't access each other's memory.

**Protection** means an application cannot read another application's data. **Isolation** means an application cannot overwrite another application's memory.

## Operating System Definition
An operating system is a layer of systems software that

* directly has privileged access to the underlying hardware, and can manipulate its state - software that corresponds to the applications is not allowed to do that;
* hides hardware complexity;
* manages hardware on behalf of one or more applications according to some predefined policies;
* ensures that applications are isolated and protected from one another.

## Operating System Examples
Certain operating systems may target the desktop or server environment, while others may target an embedded environment, while still others may target ultra high end machines like mainframes.

For our purposes, we will focus mainly on operating systems for desktop environments and embedded environments.

For desktop operating systems we have:

* Microsoft Windows
* Unix-based systems
	* OS X
	* Linux

For embedded operating systems:

* Android
* iOS
* Symbian

## OS Elements
To achieve its goals, an operating system provides a number of high level abstractions, as well as a number of mechanisms to operate on these abstractions.

*Process* and *thread* are the abstractions that correspond to the applications the operating system executes. The mechanisms that go with them are *create*, which launches an application so it starts executing, and *schedule*, which makes it actually run on the CPU.

*File*, *socket* and *memory page* are the abstractions that correspond to the hardware resources the operating system manages - a storage device, a network card, and physical memory. The mechanisms that go with them are *open*, which gains access to a particular device or hardware component, *write*, which updates its state, and *allocate*, which makes sure an application has access to that resource.

Operating systems may also integrate specific policies that determine exactly how the mechanisms will be used to manage the underlying hardware.

For example, a policy could determine the maximum number of sockets that a process has access to.

## OS Elements Example
Let's look at an example of *memory management*.

The main abstraction here is the *memory page*, which corresponds to some addressable region of memory of some fixed size - 4KB, typically.

The operating system integrates mechanisms to operate on that page like *allocate*, which actually allocates the memory in DRAM. It can also map that page into the address space of the process, so that the process can interact with the underlying DRAM.

Over time, the page may be moved to different spaces of memory, or may be moved to disk, but those who use the page abstraction don't have to worry about those details. That's the point of the abstraction.

How do we determine when to move the page from DRAM to disk? This is an example of a *policy*. Since accessing data in memory is much faster than accessing it on disk, the OS needs some rule for deciding which pages stay resident. One such implementation would use the least-recently-used (LRU) algorithm, moving pages that have been accessed longest ago onto disk. Moving a page out of physical memory and onto disk like this is called **swapping**.

A page that hasn't been touched in a while is probably not important right now and won't be needed soon, so it's cheap to evict. Pages that have been accessed more frequently are likely more important, or are part of the content the process is currently working on, so we keep them in memory.

## OS Design Principles

### Separation of mechanism and policy
We want to incorporate flexible mechanisms that can support a number of policies.

For the example of memory, we can have many policies: LRU, LFU (least-frequently used), random. It is a good design strategy to create our memory management mechanisms such that they can generalize to these different policies.

What is the mechanism that supports all three? The mechanism tracks how memory locations have been accessed, either their frequency or the time when they were last touched, or it ignores that information entirely. Any one of the three policies can be implemented on top of it.

In different settings, different policies make more sense.

### Optimize for the common case

* Where will the OS be used? What machine will it run on: how many CPUs, how much memory, what devices are attached?
* What will the user want to execute on that machine?
* What are the workload requirements? How does that workload actually behave?

Understanding the common case - which may change in different contexts - helps the OS implement the correct policy, which of course relies on generalized mechanisms.

## OS Protection Boundary
Computer systems distinguish between at least two modes of execution:

* privileged kernel mode
* unprivileged or user mode

Because an OS must have direct access to hardware, it must operate in privileged kernel mode.

Applications generally operate in unprivileged user mode.

Hardware access can only be utilized in kernel mode from the OS directly.

Crossing from user mode to kernel mode is supported by the hardware on most modern platforms.

As an example, when the CPU is in kernel mode a special bit is set in the CPU, and any instruction that directly manipulates hardware is permitted to execute. In user mode that bit is not set, and those instructions are forbidden.

When privileged instructions are encountered during a non-privileged execution, the application will be **trapped**. This means the application's execution will be interrupted, and the hardware will switch control to the OS at a specific location. At that point the OS checks what caused the trap.

The OS can decide whether to grant the access or potentially terminate the process.

The OS also exposes an interface of **system calls**, which the application can invoke, which allows privileged access of hardware resources for the application.

For example:

* `open` (file)
* `send` (socket)
* `mmap` (memory)

<details>
<summary>System calls quiz spoiler</summary>

Some other Linux system calls: `kill` sends a signal to a process, `setgid` sets the group identity of a process, `mount` mounts a file system, and `sysctl` reads or writes system parameters. On a 64 bit system the call is `setgid`; on 16 or 32 bit systems there are the variants `setgid16` and `setgid32`.

Two of those have dated since the lecture. The `setgid` variants exist because the original call took a 16 bit group ID and Linux 2.4 added a 32 bit version, so the split is about the width of the group ID rather than the word size of the machine. `sysctl` was removed from Linux in 5.5, and system parameters are now read and written through the `/proc/sys` filesystem.
</details>

Operating systems also support **signals**, which is a way for the operating system to send notifications to the application.

## System Call Flow
Begin within the context of a currently executing process. The process needs access to some hardware, and thus needs to make a system call. The application makes the system call (potentially passing arguments), and control is passed to the operating system, which accesses the hardware. Execution control (as well as any necessary data) is passed back from the operating system to the application process.

In terms of context switching, the process involves a change from user mode to kernel mode to user mode.

Not necessarily a cheap operation to make a system call!

Why isn't it cheap? Making the call changes the execution context from the user process to that of the kernel, passes whatever arguments the operation needs, and jumps to the location in kernel memory that holds the instruction sequence for that system call. The return does all of it in reverse, ending back at the exact instruction in the user process where the call was made from.

Arguments to system call can either be passed directly from process to operating system, or they can be passed indirectly by specifying their address.

In **synchronous mode**, the process waits until the system call completes. Asynchronous modes exist also.

To make a system call, the application has to:

1. Write the arguments and save the relevant data at a **well-defined location**.
2. Make the call using a specific **system call number**.

The kernel uses the system call number to work out how many arguments to expect and where to look for them.

## Crossing the OS Boundary
User/Kernel transitions are a necessary step throughout the course of application execution. An application may need to access some hardware, or it may need to request a change in the hardware resources allocated to it. Only the kernel is allowed to perform those operations - an application cannot change the contents of certain registers to give itself more CPU or more memory.

The hardware supports user/kernel transitions.

For example, the hardware will cause a *trap* on illegal executions that require special privilege.

Hardware initiates transfer of control from process to operating system when a trap occurs. Whether the OS grants or denies the request depends on the policies it supports.

User/Kernel transition requires instructions to execute, which can take 50 to 100ns on a 2Ghz Linux box.

In addition, the OS will bring the content it needs into the hardware cache, replacing the application content that was there before the transition. Where accessing the cache is on the order of a few cycles, accessing memory can be on the order of hundreds of cycles, so the application pays for those evictions on its subsequent accesses.

## OS Services
An operating system provides applications with access to the underlying hardware.

It does so by exporting a number of services, which are often directly linked to the components of the hardware:

* Scheduling component (CPU)
* Memory manager (physical memory)
* Block device driver (block device)

In addition, some services are even higher level abstractions, not having a *direct* hardware component. For example, the filesystem as a service.

Basic services include:

* Process management
* File management
* Device management
* Memory management
* Storage management
* Security

All of these services are made available to applications through system calls.

[Windows v. Unix Services](https://s3.amazonaws.com/content.udacity-data.com/courses/ud923/notes/ud923-p1l2-windows-vs-linux-system-calls.png)

Windows and Unix are very different operating systems, but the *types* of system calls they provide and the abstractions built around them line up closely. Both have process control (create a process, exit a process, wait on something), file creation, and so on.

## Monolithic OS
Historically, operating systems have a monolithic design.

Everything is included off the bat! Every possible service that any application can require, or that any type of hardware will demand, is already part of the operating system - several file systems at once, for instance.

This makes the operating system potentially very large.

#### Pros
* Everything included
* Inlining, compile-time optimizations

#### Cons
* No customization
* Not too portable/manageable
* Large memory footprint (which can impact performance)

## Modular OS
Linux uses this design, and it is the dominant approach today.

This type of operating system has a basic set of services and APIs that come with it.

Anything not included can be added, as a module.

The OS specifies an **interface** that any module must implement to plug in. Once that contract exists, you can swap the implementation behind it.

Database applications that access random offsets want a file system optimized for random access; a workload that streams through files start to finish wants one optimized for sequential access.

As a result, each application can interface with the operating systems in the ways that make most sense to it.

Dynamically install new modules in the operating system!

A smaller code base is also less resource intensive, which leaves more memory for the applications. That can lead to better performance as well.

#### Pros
* Maintainability
* Smaller footprint
* Less resource needs

#### Cons
* All the modularity/indirection can reduce some opportunities for optimization (but eh, not really)
* Maintenance can still be an issue as modules from different codebases can be slung together at runtime

## Microkernel
Microkernels only require the most basic operating system primitives: an address space and a thread, which together are enough to represent an executing application and its context.

Everything else (including file systems and disk drivers) will run outside of the operating system at unprivileged user level.

This setup requires lots of inter-process communication (IPC), as those components now live in separate processes.

As a result, the microkernel supports IPC as one of its core abstractions and mechanisms.

#### Pros
* Size (small memory footprint)
* Verifiability (great for embedded devices)

#### Cons
* Bad portability (often customized to underlying hardware)
* Harder to find common OS components due to specialized use case
* Expensive cost of frequent user/kernel crossing

**NB**: the small size keeps the memory footprint down and keeps the code base small enough to verify, but it does not make the system faster. With the file systems and the device drivers running as user level processes, an operation that is one system call in a monolithic kernel becomes several crossings and some IPC. Mach ran well behind the monolithic kernels of its day. L4 later showed that most of that gap came from Mach's IPC implementation rather than from the design.

## Linux and Mac OS Architecture

### Linux

* Hardware
* Linux Kernel
* Standard Libraries (sys call interface)
* Utility program (shells/compiler)
* User applications

Kernel consist of several logical components

* Virtual file system
* Memory management
* Process management

Each subcomponent within the three above can be modified or replaced 'cause modularity!

### Mac OS X
* I/O kit for device drivers
* Kernel extension kit for dynamic loading of kernel components
* Mach microkernel
	* memory management
	* thread scheduling
	* IPC, including remote procedure calls (RPC)
* BSD component
	* Unix interoperability
	* POSIX API support
	* Network I/O interface
* All applications sit above this layer
