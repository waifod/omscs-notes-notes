---
id: operating-systems-thread-design-considerations
title: Thread Design Considerations
course: operating-systems
lecture: thread-design-considerations
---

# Thread Design Considerations

**Reference papers**:

* [Beyond Multiprocessing: Multithreading the SunOS Kernel](https://s3.amazonaws.com/content.udacity-data.com/courses/ud923/references/ud923-eykholt-paper.pdf) - Eykholt et al.
* [Implementing Lightweight Threads](https://s3.amazonaws.com/content.udacity-data.com/courses/ud923/references/ud923-stein-shah-paper.pdf) - Stein and Shah.

**OSTEP chapters**:
* [28. Locks](https://pages.cs.wisc.edu/~remzi/OSTEP/threads-locks.pdf)
* [29. Lock-based Concurrent Data Structures](https://pages.cs.wisc.edu/~remzi/OSTEP/threads-locks-usage.pdf)
* [30. Condition Variables](https://pages.cs.wisc.edu/~remzi/OSTEP/threads-cv.pdf)
* [31. Semaphores](https://pages.cs.wisc.edu/~remzi/OSTEP/threads-sema.pdf)
* [32. Common Concurrency Problems](https://pages.cs.wisc.edu/~remzi/OSTEP/threads-bugs.pdf)

## Kernel vs. User Level Threads
Threads can be supported at the user level, the kernel level, or both.

Supporting threads at the kernel level means that the operating system itself is multithreaded. To do this the kernel must maintain some data structure to represent threads, and must also maintain all of the scheduling and syncing mechanisms to make multithreading correct and efficient.

Supporting threads at the user level means there is a user level library linked with the application that provides all of the management and support for threads. It will support the data structure as well as the scheduling mechanisms. Different processes may use entirely different user level thread libraries.

User level threads can be mapped onto kernel level threads via a 1:1, many:1 and many:many patterns.

![](https://assets.omscs.io/notes/A1FDFE7B-4F6A-4F6D-A016-A2AC1C7B64AA.png)

## Thread Related Data Structures: Single CPU
 A process is described by its process control block, which contains:
* virtual address mapping
* stack
* registers

If the process links in a user level threading library, that library will need some way to represent threads, so that it can track thread resource use and make decisions about thread scheduling and synchronization.

The library will maintain some user level thread data structure containing:
* thread ids
* thread registers
* thread stacks

If we want there to be multiple kernel level threads associated with this process, we don't want to have to replicate the entire process control block in each kernel level thread we have access to.

The solution is to split the process control block into smaller structures. Namely, the stack and registers are broken out (since these will be different for different kernel level threads) and only these pieces of information are stored in the kernel level thread data structure. The process control block keeps the virtual address mappings and everything else that is relevant to the whole process.

From the perspective of the user level threading library, the underlying kernel level threads look like virtual CPUs. The library looks at its user level threads and decides which of them will be scheduled onto the underlying kernel level threads. On Unix-based systems, the `setjmp` and `longjmp` operations are useful for saving and restoring the context of a user level thread.

![](https://assets.omscs.io/notes/A39BC8BC-E8F3-45E4-B417-921F9FA8A420.png)

## Thread Data Structures: At Scale
If we have multiple processes, we will need copies of the user level thread structures, process control blocks, and kernel level thread structures to represent every aspect of every process.

We need to start maintaining relationships among these data structures. The user level library keeps track of all of the user level threads for a given process, so there is a relationship between the user level threads and the process control block that represents that process. For each process, we need to keep track of the kernel level threads that execute on behalf of the process, and for each kernel level thread, we need to keep track of the processes on whose behalf we execute.

If the system has multiple CPUs, we need to have a data structure to represent those CPUs, and we need to maintain a relationship between the kernel level threads and the CPUs they execute on.

When the kernel itself is multithreaded, there can be multiple threads supporting a single process. When the kernel needs to context switch among kernel level threads, it can easily see if the entire PCB needs to be swapped out, as the kernel level threads point to the process on behalf of whom they are executing.

![](https://assets.omscs.io/notes/3ED34119-18EF-4B3E-98AB-E2DE92FB87DF.png)

## Hard and Light Process State
 When the operating system context switches between two kernel level threads that belong to the process, there is information relevant to both threads in the process control block, and also information that is only relevant to each thread.

Information relevant to all threads includes the virtual address mapping, while information relevant to each thread specifically can include things like signals or system call arguments. When we context switch among the two kernel level threads, we want to preserve some portion of the PCB and swap out the rest.  

We can split up the information in the process control block into **hard process state** which is relevant for all user level threads in a given process and **light process state** that is only relevant for a subset of user level threads associated with a particular kernel level thread.

![](https://assets.omscs.io/notes/E1CDE711-64D8-47BE-8793-9FA50DD7FC30.png)

## Rationale For Data Structures
Single control block:
* large continuous data structure
* private for each entity (even though some information can be shared)
* saved and restored in entirety on each context switch
* updates may be challenging

Multiple data structures:
* smaller data structures
* easier to share
* save and restore only what needs to change on context switch
* user-level library only needs to update a portion of the state for customized behavior

The single control block is worse for scalability because of its size, worse for overhead because every entity needs a private copy, worse for performance because everything is saved and restored on a context switch, and worse for flexibility because updates touch multiple operating system services. Multiple data structures are better on all four counts, which is why operating systems today organize execution context this way.

## User Level Structures in Solaris 2.0
The two reference papers of this lesson describe the kernel level and user level implementations of threads in the SunOS 5.0 kernel of Solaris 2.0. The threading model and the user level thread data structures come from Stein and Shah, *Implementing Lightweight Threads*. The kernel level structures come from Eykholt et al., *Beyond Multiprocessing: Multithreading the SunOS Kernel*.

**NB**: The lightweight threads library described here is not pthreads, but it is a similar kind of user level threading library.

### Threading Model
![](https://assets.omscs.io/notes/0C4D3FA7-A3C9-4469-B87B-050484774183.png)

The OS is intended for multiple CPU platforms and the kernel itself is multithreaded. At the user level, the processes can be single or multithreaded, and both many:many and one:one user level thread (ULT) to kernel level thread (KLT) mappings are supported.

Each kernel level thread that is executing on behalf of a user level thread has a **lightweight process** (LWP) data structure associated with it. From the user level library perspective, these LWPs represent the virtual CPUs onto which the user level threads are scheduled. At the kernel level, there will be a kernel level scheduler responsible for scheduling the kernel level threads onto the CPU.

### User Level Thread Data Structures
When a thread is created, the library returns a thread id. This id is not a direct pointer to the thread data structure but is rather an index into an array of thread pointers.

The nice thing about this is that if there is a problem with the thread, the value at the index can change to say -1 instead of the pointer just pointing to some corrupt memory.

The thread data structure contains different fields for:

- execution context
- registers
- signal mask
- priority
- stack pointer
- thread local storage
- stack

The amount of memory needed for a thread data structure is often almost entirely known upfront at compile time. This allows for compact representation of threads in memory: basically, one right after the other in a contiguous section of memory. This gives us locality, and it makes finding the next thread cheap - the scheduler just multiplies the thread index by the size of the data structure.

However, the user library does not control stack growth, and the operating system does not even know that there are multiple user level threads. With this compact memory representation, there may be an issue if one thread starts to overrun its boundary and overwrite the data for the next thread. If this happens, the problem is that the error won't be detected until the overwritten thread starts to run, even though the cause of the problem is the overwriting thread.

The solution is to separate information about each thread by a **red zone**. The red zone is a portion of the virtual address space that is not allocated. If a thread tries to write to a red zone, the operating system causes a fault. Now it is much easier to reason about what happened as the error is associated with the problematic thread.

![](https://assets.omscs.io/notes/8D7A444B-90D8-451B-9DA4-8D2B8D1D1239.png)

## Kernel Level Structures in Solaris 2.0
For each process, the kernel maintains a bunch of information, such as:

- list of kernel level threads
- virtual address space
- user credentials
- signal handlers

For each kernel level thread, the kernel also maintains the lightweight process (LWP) introduced above, which contains data that is relevant for some subset of the user threads in a given process. The data contained in an LWP includes:

- user level registers
- system call arguments
- resource usage info
- signal masks

The data contained in the LWP is similar to the data contained in the ULT, but the LWP is visible to the kernel. When the kernel needs to make scheduling decisions, it can look at the LWP.

The kernel tracks resource usage on a per kernel level thread basis, and that information lives in the LWP corresponding to that kernel level thread. To find the aggregate resource usage for an entire process, we have to walk through all of the LWPs associated with it.

The kernel level thread contains:

- kernel-level registers
- stack pointer
- scheduling info
- pointers to associated LWPs, and CPU structures

The kernel level thread has information about an execution context that is always needed. There are operating system services (for example, scheduler) that need to access information about a thread even when the thread is not active. As a result, the information in the kernel level thread is **not swappable**. The LWP data does not have to be present when the process is not running, so under memory pressure the kernel can swap it out. This lets the system support a larger number of threads in a smaller memory footprint than would be possible if everything had to stay resident.

The CPU data structure contains:

- current thread
- list of kernel level threads
- dispatching & interrupt handling information

Given a CPU data structure it is easy to traverse and access all the other linked data structures. In SPARC machines (what Solaris runs on), there is a dedicated register that holds the thread that is currently executing. This makes it even easier to identify and understand the current thread.

![](https://assets.omscs.io/notes/D37A8ECF-B01C-4FEC-9B55-8FB7C938B26B.png)

A process data structure has information about the user and points to the virtual address mapping data structure. It also points to a list of kernel level threads. Each kernel level thread structure points to the lightweight process and the stack, which is swappable.

![](https://assets.omscs.io/notes/69BD0A17-1A53-48B8-940A-9B4B96722D25.png)

## Basic Thread Management Interaction
Consider a process with four user threads. However, the process is such that at any given point in time the actual level of concurrency is two. It always happens that two of its threads are blocking on, say, IO and the other two threads are executing.

If the operating system has a limit on the number of kernel threads that it can support, the application might have to request a fixed number of threads to support it. The application might select two kernel level threads, given its concurrency.

<details>
<summary>Number of threads quiz spoiler</summary>

Linux also enforces a minimum. Some threads have to be available at startup just to get the operating system to boot. In the 3.17 source, the fork initialization code in `fork.c` ensures that at least 20 threads can be created for this purpose, and the variable that holds the limit is `max_threads`.
</details>

When the process starts, maybe the operating system only allocates one kernel level thread to it. The application may specify (through a `set_concurrency`  system call) that it would like two threads, and another thread will be allocated.

<details>
<summary>PThread concurrency quiz spoiler</summary>

In pthreads the corresponding call is `pthread_setconcurrency`. The application can pass an exact value, like the two kernel level threads above, or it can pass 0, which asks the implementation to decide. The call is only a hint, and it is meaningful only on many:many implementations. Linux uses a 1:1 model, so there it has no effect.
</details>

Consider the scenario where the two user level threads that are scheduled on the kernel level threads happen to be the two that block.  The kernel level threads block as well. This means that the whole process is blocked, even though there are user level threads that can make progress. The user level library has no way to know that the kernel level threads are about to block, so it cannot react before that happens.

What would be helpful is if the kernel was able to signal to the user level library *before* blocking, at which point the user level library could potentially request more kernel level threads. The kernel could allocate another kernel level thread to the process temporarily. Once the kernel notices that thread sitting idle, it tells the library that the thread has been taken away.

Generally, the problem is that the user level library and the kernel have no insight into one another. To solve this problem, the kernel exposes system calls and special signals to allow the kernel and the ULT library to interact and coordinate.

## Thread Management Visibility and Design
The kernel sees:

- Kernel level threads
- CPUs
- Kernel level scheduler

The user level library sees:

- User level threads
- Available kernel level threads

The user level library can request that one of its threads be bound to a kernel level thread.  This means that this user level thread will always execute on top of a specific kernel level thread. This may be useful if in turn the kernel level thread is pinned to a particular CPU.

If a user level thread acquires a lock while running on top of a kernel level thread and that kernel level thread gets preempted, the user level library scheduler will cycle through the remaining user level threads and try to schedule them. If they need the lock, none will be able to execute and time will be wasted until the thread holding the lock is scheduled again.

The user level library will make scheduling changes that the kernel is not aware of which will change the ULT/KLT mapping in the many to many case.  Also, the kernel is unaware of the data structures used by the user level, such as mutexes and wait queues.

We should look at 1:1 ULT:KLT models.

The process jumps to the user level library scheduler when:

- ULTs explicitly yield
- Timer set by the by UL library expires
- ULTs call library functions like lock/unlock
- blocked threads become runnable

The library scheduler may also gain execution in response to certain signals from timers and/or the kernel.

## Issue On Multiple CPUs
In a multi CPU system, the kernel level threads that support a process may be running concurrently on multiple CPUs. We may have a situation where the user level library that is operating in the context of one thread on one CPU needs to somehow impact what is running on **another** CPU.

Scenario
![](https://assets.omscs.io/notes/8859114F-5FA0-445D-9B5D-9324D73FC541.png)

We have three user level threads with priorities: T3 is highest, then T2, and T1 is lowest. Currently, T2 is holding the mutex and is executing on one CPU. T3, the highest priority thread, wants the mutex and is currently blocking. T1 is running on the other CPU.

At some point, T2 releases the mutex, and T3 becomes runnable. All three threads are now runnable, and we have to make sure the highest priority ones execute. T1 has the lowest priority, so T1 needs to be preempted - but we make this realization from the user level thread library as T2 is unlocking the mutex. We need to preempt a thread on a different CPU!

We cannot directly modify the registers of one CPU when executing as another CPU. We need to send a signal from the context of one thread on one CPU to the context of the other thread on the other CPU, to tell the other CPU to execute the library code locally, so that the proper scheduling decisions can be made.

Once the signal occurs, the library code can block T1 and schedule T3, keeping with the thread priorities within the application.


## Synchronization Related Issues
Scenario
![](https://assets.omscs.io/notes/EA93A7AA-BDE7-492C-8001-B4DE63CA8BD4.png)

T1 holds the mutex and is executing on one CPU. T2 and T3 are blocked. T4 is executing on another CPU and wishes to lock the mutex.

The normal behavior would be to place T4 on the queue associated with the mutex. However, on a multiprocessor system where things can happen in parallel, it may be the case that by the time T4 is placed on the queue, T1 has released the mutex.

If the critical section is very short, the more efficient case for T4 is not to block, but just to spin (trying to acquire the mutex in a loop).  If the critical section is long, it makes more sense to block (that is, be placed on a queue and retrieved at some later point in time). This is because it takes CPU cycles to spin, and we don't want to burn through cycles for a long time.

Mutexes which sometimes block and sometimes spin are called **adaptive mutexes.** These only make sense on multiprocessor systems, since we only want to spin if the owner of the mutex is currently executing in parallel to us.

We need to store some information about the owner of a given mutex at a given time, so we can determine if the owner is currently running on a CPU, which means we should potentially spin. Also, we need to keep some information about the length of the critical section, which will give us further insight into whether we should spin or block.

Once a thread is no longer needed, the memory associated with it should be freed. However, thread creation takes time, so it makes sense to reuse the data structures instead of freeing and creating new ones.

When a thread exits, the data structures are not immediately freed. Instead, the thread is marked as being on **death row**. Periodically, a special **reaper** thread will perform garbage collection on these thread data structures. If a request for a thread comes in before a thread on death row is reaped, the thread structure can be reused, which results in some performance gains.

## Interrupts and Signals Intro

### Interrupts
Interrupts are events that are generated **externally** by components other than the CPU to which the interrupt is delivered. Interrupts are notifications that some external event has occurred.

Components that may deliver interrupts can include:

- I/O devices
- Timers
- Other CPUs

Which particular interrupts can occur on a given physical platform depends on the configuration of that platform, the types of devices the platform comes with, and the hardware architecture of the platform itself.

Interrupts appear **asynchronously**. That is, they do not appear in response to any specific action that is taking place on the CPU.

### Signals
Signals are events that are triggered by the CPU and the software running on it.

Which signals can occur on a given platform depends very much on the given operating system. Two identical platforms will have the same interrupts but will have different signals if they are running different operating systems.

Unlike interrupts, signals can appear both synchronously and asynchronously. Signals can occur in direct response to an action taken by a CPU - a process touching memory that was not allocated to it, for example - or they can manifest similar to interrupts.

### Signal/Interrupt Similarities

Both signals and interrupts have a unique identifier whose values depend on the hardware or operating system.

Both interrupts and signals can be **masked**. An interrupt can be masked on a per-CPU basis and a signal can be masked on a per-process basis. A mask is used to disable or delay the notification of an incoming interrupt or signal.

Why the different granularity? The interrupt mask is associated with a CPU because interrupts are delivered to the CPU as a whole. The signal mask is associated with a process because signals are delivered to individual processes.

If the mask indicates that the corresponding interrupt or signal is enabled, the incoming notification will trigger the corresponding handler. Interrupt handlers are specified for the entire system, by the operating system. Signal handlers are set on a per-process basis, by the process itself.

## Interrupt Handling
When a device wants to send a notification to the CPU, it sends an interrupt by sending a signal through the interconnect that connects the device to the CPU.

Most modern devices use a special message, **MSI** that can be carried on the same interconnect that connects the device to the CPU complex. Based on the pins on where the interrupt is received or the message itself, the interrupt can be uniquely identified.

The interrupt interrupts the execution of the thread that was executing on top of the CPU, so now what? The CPU looks up the interrupt number in a table and executes the handler routine that the interrupt maps to. The interrupt number maps to the starting address of the handling routine, and the program counter can be set to point to that address to start handling the interrupt.

All of this happens within the context of the thread that is interrupted.

Which interrupts can occur depends on the *hardware* of the platform and how the interrupts are handled depends on the *operating system* running on the platform.

![](https://assets.omscs.io/notes/8CCF2340-EEDB-42B7-B8BA-DDC9E7BC75BE.png)

## Signal Handling
Signals are different from interrupts in that signals originate from the CPU. For example, if a process tries to access memory that has not been allocated, the operating system will generate a signal called SIGSEGV.

For each process, the OS maintains a mapping where the keys correspond to the signal number (SIGSEGV is signal 11, for example), and the values point to the starting address of handling routines. When a signal is generated, the program counter is adjusted to point to the handling routine for that signal for that process.

![](https://assets.omscs.io/notes/5F7DBAFC-B0F5-422D-B6B3-F29660E99E97.png)

The process may specify how a signal can be handled, or the operating system default may be used. Some default signal responses include:

- Terminate
- Ignore
- Terminate and Core Dump
- Stop
- Continue (from stopped)

For most signals, processes can install its custom handling routine, usually through a system call like `signal` or `sigaction` although there are some signals which cannot be caught.

Some synchronous signals include:

- SIGSEGV
- SIGFPE (divide by zero)
- SIGKILL (from one process to another)

Some asynchronous signals include:

- SIGKILL (as the receiver)
- SIGALARM (timeout from timer expiration)

<details>
<summary>Signals quiz spoiler</summary>

The POSIX `signal.h` header tabulates the full set of signals, with each signal's default action and description. Matching a few events to names from that table: the terminal interrupt signal is SIGINT, high bandwidth data available on a socket is SIGURG, a background process attempting to write is SIGTTOU, and file size limit exceeded is SIGXFSZ.

Two of those descriptions are POSIX's own wording, and both are looser than the behaviour. SIGURG is raised when out-of-band, or urgent, data arrives on a socket, which has nothing to do with bandwidth. SIGTTOU applies to a background process group writing to its controlling terminal, and only when the terminal's `TOSTOP` flag is set; a background process writing to a file or a pipe does not get it.
</details>

## Why Disable Interrupts or Signals?
Interrupts and signals are handled in the context of the thread being interrupted/signaled. This means that they are handled on the thread's stack, which can cause certain issues.

When a thread handles a signal, the program counter of the thread will point to the first address of the handler. The stack pointer will remain the same, meaning that whatever the thread was doing before being interrupted will still be on the stack. Multiple interrupts or signals will keep stacking their handlers on the stack of the thread that was originally interrupted.

If the handling code needs to access some shared state that can be used by other threads in the system, we will have to use mutexes. If the thread which is being interrupted had already locked the mutex before being interrupted, we are in a **deadlock**. The thread can't unlock its mutex until the handler returns, but the handler can't return until it locks the mutex.

To prevent this situation, we can enforce that the handling code stays simple and make sure it doesn't do things like try to acquire mutexes. This of course is too restrictive.

A better solution is to use **signal/interrupt masks**. These masks allow us to dynamically make decisions as to whether or not signals/interrupts can interrupt the execution of a particular thread.

The mask is a sequence of bits where each bit corresponds to an interrupt or signal and the value - 0 or 1 - signifies whether or not this particular interrupt or signal is disabled or enabled.

When an event occurs, first the mask is checked to determine whether a given interrupt/signal is enabled. If the event is enabled, we proceed with the actual handling code. If the event is disabled, the interrupt/signal is made pending and will be handled at a later time when the mask changes.

To solve the deadlock situation, described above, we must disable the interrupt/signal before acquiring the mutex, and re-enable the interrupt/signal after releasing the mutex. This will ensure that we are never in the handler code when the mutex is locked.

Once the signal is re-enabled, the pending signal is handled by the handler.

While an interrupt or signal is pending, other interrupts or signals may also become pending. Typically the handling routine will only be executed once, so if we want to ensure a signal handling routine is executed more than once, it is not sufficient to just generate the signal more than once.

## More on Signal Masks
Interrupt masks are maintained on a per CPU basis. This means that if a mask disables an interrupt, the hardware interrupt routing mechanism will not deliver the interrupt to the CPU.

Signal masks are maintained on a per execution context (ULT on top of KLT). If a mask disables a signal, the kernel will see this and will not interrupt the corresponding execution context.

## Interrupts on Multicore Systems
On a multi CPU system, the interrupt routing logic will direct the interrupt to any CPU that at that moment in time has that interrupt enabled. One strategy is to enable interrupts on just one CPU, which will allow avoiding any of the overheads or perturbations related to interrupt handling on any of the other cores. The net effect will be improved performance.

## Types of Signals
There are two types of signals.

**One-shot signals** refer to signals that will be handled at least once. This means that from the perspective of the user level thread, n signals may look exactly like one signal. One-shot signals must also have their handling routine explicitly re-enabled every time. If a process installs a custom handler and does not reinstall it, the next instance of that signal is handled by the operating system default action instead - and if the default is to ignore the signal, it is simply lost.

**Real-Time Signals** refer to signals that will interrupt as many times as they are raised. If n signals occur, the handler will be called n times. They queue rather than override.

## Interrupts as Threads
To avoid the deadlock situation we covered before with regards to handler code trying to lock a mutex that the thread had already locked, perhaps it makes sense to have handler code exist in its own thread. This is the approach described in the SunOS paper.

This way, when the handler thread tries to acquire the mutex, it will block just like any other thread instead of deadlocking. The handler thread and its context are placed on the wait queue associated with the mutex, and the original thread is scheduled back on the CPU. Eventually, the original thread unlocks the mutex, the handler thread is dequeued, and the handling routine completes.

Dynamic thread creation is expensive! We only want to create a new thread if we need one. We cannot wait to see whether a handler blocks, so Solaris decides by looking for locks: if the handler routine contains no locks, it cannot block, so we can safely run it on the stack of the interrupted thread. Only if the handler might lock a mutex do we turn it into a real thread.

To eliminate the cost of dynamic thread creation, the kernel pre-creates and pre-initializes thread structures for the interrupt routines it supports, pointing them at the appropriate handling routine and allocating their internal data upfront. We then don't pay the creation cost when an interrupt actually occurs.

## Interrupts: Top vs. Bottom Half
When an interrupt first occurs, it may still be necessary to disable certain interrupts, since that is one way to prevent the deadlock situation. But once handling is passed to a separate thread, we can re-enable whatever we disabled. Interrupts arriving now are handled the same way they would be for any other thread in the system, so there is no additional danger of deadlock.

There are two components of interrupt handling. The **top half** occurs in the context of the interrupted thread, before the handler thread is created. It executes immediately when the interrupt occurs, so it must be fast, non-blocking, and do a minimal amount of processing. The **bottom half** is everything that runs once we have created the handler thread. It can contain arbitrary complexity, since we have stepped out of the context of our main program into a separate thread: like any other thread, it can be scheduled for a later time and it can block.

**NB**: Linux uses these same names for the two parts of interrupt processing.

![](https://assets.omscs.io/notes/CB177F61-F635-4014-B166-2C9DDFE51FA3.png)

## Performance of Threads as Interrupts
The overhead of performing the necessary checks and potentially creating a new thread in the case of an interrupt adds about 40 SPARC instructions to each interrupt handling operation.

As a result, it is no longer necessary to change the interrupt mask before locking a mutex and change it back after releasing the mutex, which saves about 12 instructions per mutex operation.

Since mutex lock/unlocks occur much more frequently than interrupts, the net instruction count is decreased when using the interrupt as threads strategy.

In general, it is a solid strategy to optimize for the common case. We could have scenarios in which interrupts occur more than mutex lock/unlocks, but we have assumed this is rarely the case, and have optimized for the reverse.

## Threads and Signal Handling
Each user level thread has its own signal mask. That mask lives at user level and is visible to the user level threading library, but not to the kernel. Each kernel level thread also has a signal mask - it actually lives in the lightweight process attached to that kernel level thread - and this mask is visible only to the kernel.

When a user level thread wants to disable a signal, it clears the appropriate bit in its own mask. This happens entirely at user level, so the kernel level mask is not updated.

When a signal occurs, the kernel needs to know what to do with the signal. The kernel mask may have that signal bit set to one, so from the kernel's point of view, the signal is still enabled.

If we don't want to have to make a system call, crossing from user level into kernel level each time a user level threads updates the signal mask, we need to come up with some kind of policy. The lightweight threads paper proposes a solution.

The user level threading library, not the application, installs the signal handlers. For every signal in the system the library installs a **wrapper** of its own around the application's real handler, so the library always sees the signal before the real handler does. The library can also see the masks of every user level thread in the process.

### Case 1
Both the kernel level mask and the mask of the currently executing user level thread have the bit for this signal enabled. The kernel delivers the signal to the currently running user level thread, that thread can handle it, and there is no problem.

### Case 2
The kernel level mask has the bit enabled and the currently executing user level thread does not. However, there is another user level thread that does have the bit enabled, and it is runnable but not currently running.

We want to stop the thread that cannot handle the signal and start the one that can.

The library wrapper can see the masks of all of the user level threads. Since the currently scheduled thread cannot handle the signal but a runnable one can, the library invokes its scheduler to swap in the thread that can handle the signal. Once this thread is executing, the signal is passed to its handler.

![](https://assets.omscs.io/notes/0F15B3F6-6413-476B-A93E-68701ED3F138.png)

### Case 3
User level threads are executing concurrently atop two kernel level threads. Both kernel level masks have the bit enabled, while only one of the user level thread masks does. The user level thread that can handle the signal is not sitting on the run queue; it is already running, on another kernel level thread on another CPU.

The signal is delivered in the context of the kernel level thread whose user level thread does *not* have the bit enabled. The library wrapper kicks in and knows it cannot pass the signal to this particular user thread.

What it can do, however, is send a directed signal down to the kernel level thread - the lightweight process - where the user level thread that has the bit enabled is executing. The kernel sees that kernel level mask enabled and delivers the signal there. The signal lands in the library wrapper again, which this time sees that the currently running user level thread can handle the signal, and lets the real handler execute.

![](https://assets.omscs.io/notes/E1D06396-5CD0-49B4-8D7F-9BF845406CE3.png)

### Case 4
Every single user thread has the particular signal disabled. The kernel level masks are still 1, so the kernel still thinks that the process as a whole can handle the signal.

When the signal occurs, the kernel delivers it to one of those kernel level threads, interrupting whichever user level thread is executing on top of it. The library wrapper kicks in and sees that no threads that it manages can handle this particular signal.

![](https://assets.omscs.io/notes/29F3EC50-8F5A-4B22-BEC7-AB02E7914399.png)

At this point, the thread library will make a system call requesting that this kernel level thread change its signal mask for this particular signal, disabling it.

We can only change the mask of the kernel level thread we are executing on, so the library reissues the signal for the entire process. The kernel delivers it to another kernel level thread whose mask still has the signal enabled. The wrapper kicks in there, disables that mask by system call, and reissues again. This repeats until every kernel level mask in the process has the signal disabled.

At some point in time, a user level thread may decide to re-enable a particular signal. Since the library knows it has already disabled all of the kernel level masks, it must again make a system call and update one of them, so that the kernel once more sees the process as capable of handling the signal.

Here we optimize for the common case again. Signals themselves occur much less frequently than does the need to update the signal mask. Updates of the signal mask are cheap. They occur at the user level and avoid system calls. Signal handling becomes more expensive, since system calls may be needed to correct discrepancies, but signals are rare enough that the added cost is acceptable.

## Tasks in Linux
The main abstraction that Linux uses to represent an execution context is called a **task**. A  task is essentially the execution context of a kernel level thread. A single-threaded process will have one task, and a multithreaded process will have many tasks.

Key elements in task structure, encapsulated by `struct task_struct`
![](https://assets.omscs.io/notes/8B519534-0C74-4A8A-841A-1DCCE73AEFF7.png)

A task is identified by its `pid_t pid`. If we have a single-threaded process the id of the task and the id of the process will be the same. If we have a multithreaded process, each task will have a different `pid` and the process as a whole will be identified by the `pid` of the first task that was created. This information is also captured in the `pid_t tgid` or task group id, field.

The task structure maintains a list of all of the tasks for a process, whose head is identified by `struct list_head tasks`.

Linux never had one contiguous process control block. Instead,  the process state was always maintained through a collection of data structures that pointed to each other. We can see some of the references in the task in `struct mm_struct *mm` and `struct files_struct *files`. This makes it easy for tasks within a single process to share portions of the state - the virtual address mappings, the open files - since those pointers simply point at the same structure. The task structure is roughly 1.7 KB, so there is a lot more in it than what we show here.

To create a new task, Linux supports an operation called `clone`. It takes a function pointer and an argument (similar to `pthread_create`) but it also takes an argument `sharing_flags` which denotes which portion of the state of a task will be shared between the parent and child task.

![](https://assets.omscs.io/notes/B717E81B-24EA-4742-833B-C35C128E0A0A.png)

When all of the bits are set, we are creating a new thread where the state is shared with the parent thread. If all of the bits are cleared, we are not sharing anything, which is more akin to creating an entirely new process. In fact, `fork` in Linux is implemented by `clone` with all sharing flags cleared. Various combinations in between make sense too - we may want to share the files with the child task but nothing else.

**NB**: `fork` has different semantics for multithreaded and single-threaded processes. Forking a single-threaded process gives us a child that is a full replica of the parent. Forking a multithreaded process gives us a child that is single-threaded, replicating only the portion of the state visible from the task that called `fork`. This has implications for synchronization and what happens to mutexes, which are beyond the scope of this class.

The native implementation of threads in Linux is the **Native POSIX Threads Library (NPTL)**. This is a 1:1 model, meaning that there is a kernel level task for each user level thread. This implementation replaced an earlier implementation **LinuxThreads**, which was a many-to-many model.

In NPTL, the kernel sees every user level thread. This is acceptable because kernel trapping has become much cheaper, so user/kernel crossings are much more affordable. Also, modern platforms have more memory - removing the constraints to keep the number of kernel threads as small as possible.

That being said, when we talk about extremely large numbers of threads (exascale computing, for example) or about complex heterogeneous platforms with different kinds of processors, it may make sense to revisit user level library support and more custom threading policies. For most practical purposes, though, the 1:1 model in current Linux is completely sufficient.
