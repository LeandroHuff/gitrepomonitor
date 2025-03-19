# Git Repository Monitor aka gitrepomonitor

The gitrepomonitor is a shell script program the run as a daemon service on Linux.
The purpose for this project is to automate the update procedures to let the local repositories up to date with online github repositories.
To do it, this daemon read a file with a list of personal github repositories names, check each one to find out of date repository, if someone in file list is out of date and need to be syncronized to online github account, the script run all commands to add all untracked, deleted or changed local files, commit with a formatted message (formatted message + date and time) and push all to online git repository respectivally and automated.
The ideas to build this project came from the repository daemons that store this project and dive deeply into the concepts and architecture of deamons on Linux system. All projects and ideas was built thinking for Linux Operating System, but with few changes all of them can be run on others OS too.
Following this document, I include some usefull information about daemon concept and its algoritms, source code format and how it could be implemented, these information was taken from others blogs and articles that teatch about how to create and implement a simple program (binary) or script (shell, python, perl, etc) to run as a daemon service on Linux system.

# How to Create a Daemon Service in Linux

In a Unix environment, the parent process of a daemon is often, but not always, the init process. A daemon is usually created either by a process forking a child process and then immediately exiting, thus causing init to adopt the child process, or by the init process directly launching the daemon.

### This involves a few steps:

Fork off the parent process.
Change file mode mask (umask)
Open any logs for writing.
Create a unique Session ID (SID)
Change the current working directory to a safe place.
Close standard file descriptors.
Enter actual daemon code.
Daemon - Run in the Background

The daemon() function is for programs wishing to detach themselves from the controlling terminal and run in the background as system daemons. If nochdir is zero, daemon() changes the process's current working directory to the root directory ("/"); otherwise, the current working directory is left unchanged. If noclose is zero, daemon() redirects standard input, standard output, and standard error to /dev/null; otherwise, no changes are made to these file descriptors.

### Here are the steps to become a daemon:

1. fork() so the parent can exit, this returns control to the command line or shell invoking your program. This step is required so that the new process is guaranteed not to be a process group leader. The next step, setsid(), fails if you're a process group leader.
2. setsid() to become a process group and session group leader. Since a controlling terminal is associated with a session, and this new session has not yet acquired a controlling terminal our process now has no controlling terminal, which is a Good Thing for daemons. 
3. fork() again so the parent, (the session group leader), can exit. This means that we, as a non-session group leader, can never regain a controlling terminal. 
4. chdir("/") to ensure that our process doesn't keep any directory in use. Failure to do this could make it so that an administrator couldn't unmount a filesystem, because it was our current directory. [Equivalently, we could change to any directory containing files important to the daemon's operation.] 
5. umask(0) so that we have complete control over the permissions of anything we write. We don't know what umask we may have inherited. [This step is optional] 6. close() fds 0, 1, and 2. This releases the standard in, out, and error we inherited from our parent process. We have no way of knowing where these fds might have been redirected to. Note that many daemons use sysconf() to determine the limit _SC_OPEN_MAX. _SC_OPEN_MAX tells you the maximun open files/process. Then in a loop, the daemon can close all possible file descriptors. You have to decide if you need to do this or not. If you think that there might be file-descriptors open you should close them, since there's a limit on number of concurrent file descriptors. 
6. Establish new open descriptors for stdin, stdout and stderr. Even if you don't plan to use them, it is still a good idea to have them open. The precise handling of these is a matter of taste; if you have a logfile, for example, you might wish to open it as stdout or stderr, and open '/dev/null' as stdin; alternatively, you could open '/dev/console' as stderr and/or stdout, and '/dev/null' as stdin, or any other combination that makes sense for your particular daemon.

```
/* daemonsample.c */

#include <sys/types.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <linux/fs.h>

int main (void)
{
   pid_t pid;
   int i;

   /* create new process */
   pid = fork();
   if (pid == -1)
   {
      return -1;
   }
   else
   {
      if (pid != 0)
      {
         exit (EXIT_SUCCESS);
      }
   }

   /* create new session and process group */
   if (setsid() == -1)
   {
      return -1;
   }

   /* set the working directory to the root directory */
   if (chdir ("/") == -1)
   {
      return -1;
   }

   /* close all open files--NR_OPEN is overkill, but works */
   for (i = 0; i < NR_OPEN; i++)
   {
      close(i);
   }

   /* redirect fd's 0,1,2 to /dev/null */
   open("/dev/null", O_RDWR);

   /* stdin */
   dup(0);

   /* stdout */
   dup(0);

   /* stderror */
   dup(0);

   /* start from here, do its daemon thing as an infinite looping for example */


   /* end of daemon */
   return 0;
}
```

Daemon is called as a type of program which quietly runs in the background rather than under the direct control of a user. It means that a daemon does not interact with the user.

Systemd Management of daemons is done using systemd. It is a system and service manager for Linux operating systems. It is designed to be backwards compatible with SysV init scripts, and provides a number of features such as parallel startup of system services at boot time, on-demand activation of daemons, or dependency-based service control logic.

Units Systemd introduced us with the concept of systemd units. These units are represented by unit configuration files located in one of the directories listed below:

| Directory                | Description                                                                                                                                                                     |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| /usr/lib/systemd/system/ | Systemd unit files distributed with installed RPM packages.                                                                                                                     |
| /run/systemd/system/     | Systemd unit files created at run time. This directory takes precedence over the directory with installed service unit files.                                                   |
| /etc/systemd/system/     | Systemd unit files created by systemctl enable as well as unit files added for extending a service. This directory takes precedence over the directory with runtime unit files. |

## Creating our own daemon

At many times we will want to create our own services for different purposes. For this we will be using a **Java** application, packaged as a jar file and then we will make it run as a service.

Step 1: JAR File The first step is to acquire a jar file. We have used a jar file which has implemented a few routes in it.

Step 2: Script Secondly, we will be creating a bash script that will be running our jar file. Note that there is no problem in using the jar file directly in the unit file, but it is considered a good practice to call it from a script. It is also recommended to store our jar files and bash script in /usr/bin directory even though we can use it from any location on our systems.

```
#!/bin/bash
/usr/bin/java -jar <name-of-jar-file>.jar
```

Make sure that you make this script executable before running it:

```
chmod +x <script-name>.sh
```

Step 3: Units File Now that we have created an executable script, we will be using it into make our service. We have here a very basic .service unit file.

```
[Unit]
Description=A Simple Java Service

[Service]
WorkingDirectory=/usr/bin
ExecStart= /bin/bash /usr/bin/java-app.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

In this file, the Description tag is used to give some detail about our service when someone will want to see the status of the service. The WorkingDirectory is used to give path of our executables. ExecStart tag is used to execute the command when we start the service. The Restart tag configures whether the service shall be restarted when the service process exits, is killed, or a timeout is reached. multi-user.target normally defines a system state where all network services are started up and the system will accept logins, but a local GUI is not started. This is the typical default system state for server systems, which might be rack-mounted headless systems in a remote server room.

Step 4: Starting Our Daemon Service Let us now look at the commands which we will use to run our custom daemon.

sudo systemctl daemon-reload

Uncomment the below line to start your service at the time of system boot

```
# sudo systemctl enable <name-of-service>.service
sudo systemctl start <name-of-service>
```

OR

```
# sudo service <name-of-service> start
sudo systemctl status <name-of-service>
```

OR

```
# sudo service <name-of-service> status
```

Conclusion, we have looked how to make custom daemons and check their status as well. Also, we observed that it is fairly easy to make these daemons and use them. We hope that everyone is now comfortable enough to make daemons on their own.

## References:

https://dzone.com/articles/run-your-java-application-as-a-service-on-ubuntu

https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/system_administrators_guide/chap-managing_services_with_systemd

## DaemonSample.c

This project is a simple Linux Daemon demonstration with a minimal software code to demonstrate and run the process for a while in seconds until finish it. The time in seconds to wait until finish is passed from command line as an argument to the DaemonSample software. The daemon process wont do anything, just sleep for 1s while decrement a counter wainting to reach zero, for each interation, the daemon software sleep and at the end of counter time the daemon stop and return. The daemon running could be viewed by htop linux tool and filtered by name pressing F4 to enter "DaemonSample" name.

Sintaxe: ./DaemonSample 10

Start the DaemonSample and wait for 10 seconds until to stop itself.

To watch the DaemonSample running, execute htop linux command as:

htop

Inside the htop program, hit F4 and write DaemonSample and press Enter to filter all process by this name. The htop process list will be reduced to only one process with name DaemonSample, if it is running. After time elapsed the process is stoped and the htop remove the DaemonSample program from the list to show that the process was finished.

This example can be improved according to your needs and the application of your daemon process, be free to use it as your convenience. I hope you enjoy it and this example can be useful to your self development and application.

# Shell Script as Daemon Service (a bash Shell Script Program)

Sometimes we need to implement a shell script as a daemon service, from here we'll demonstrate how to do this.

## Service Daemons

Systemd is a suite of system management daemons, libraries, and utilities designed to centralize the management of various aspects of a Linux OS.

It provides a standard process for controlling what programs run when a Linux OS boots up and during its ope'ration.

Systemd service file is a plain text file with the ‘.service’ extension contains configuration directives for a service.

These directives define how a service should be started, stopped, and managed. Let's break down the key sections of a Systemd service file:

```
service [Script] [Action] [Option]
```

• start: Starts the script.
• stop: Stops the script.
• status: Shows the current status of the script.
• restart: Ensures that the script is restarted.

```
sudo service command/script start
sudo service command/script stop
sudo service command/script restart
sudo service command/script status
```

### Unit Section:

The `[Unit]` section provides metadata about the service. It includes the `Description`, which is a brief description of the service, and other optional fields like `After` to specify service dependencies.

```
[Unit]
 Description=My Custom Service
 After=network.target
```

### Service Section:

The `[Service]` section contains directives related to how the service should be executed. The most important directive is `ExecStart`, which specifies the command or script to run as the service.

```
[Service]
 ExecStart=/path/to/your/command
```

### Additional directives can set the working directory, user, group, and configure restart behavior:

```
WorkingDirectory=/path/to/your/working/directory
 User=your_username
 Group=your_group_name
 Restart=always
 RestartSec=3
```

### Install Section:

The `[Install]` section specifies when and how the service should be started or enabled. The `WantedBy` directive determines the target at which the service should start, such as `multi-user.target` for services that run after boot.

```
[Install]
 WantedBy=multi-user.target
```

## Writing a Systemd Service File

Now that we understand the structure, let’s create a simple Systemd service file. Imagine we want to run a custom script located at `/opt/my_script.sh` as a background service.

### Create the Service File

```
sudo nano /etc/systemd/system/my_custom_service.service
```

### Write the Service File

```
[Unit]
 Description=My Custom Service
 After=network.target

[Service]
 ExecStart=/opt/my_script.sh
 WorkingDirectory=/opt
 User=myuser
 Restart=always
 RestartSec=3

[Install]
 WantedBy=multi-user.target
```

Adjust the paths, user, and other settings to match your specific use case.

### Save and Reload Systemd

Save the file and exit the text editor. Then, reload Systemd to read the new service file:

```
sudo systemctl daemon-reload
```

### Start and Enable the Service

You can now start and enable your service:

```
sudo systemctl start my_custom_service
sudo systemctl enable my_custom_service
```

Replace **my_custom_service** with the actual service name.

### Check the Service Status

Verify that your service is running without errors

```
sudo systemctl status my_custom_service
```

### Managing Systemd Services

Systemd provides a set of commands to manage services, such as

- systemctl start service_name  : Start a service.
- systemctl stop service_name   : Stop a service.
- systemctl restart service_name: Restart a service.
- systemctl status service_name : Display the status of a service.
- systemctl enable service_name : Enable a service to start at boot.
- systemctl disable service_name: Disable a service from starting at boot.

| Unit Type      | File Extension | Description                                                             |
| -------------- | -------------- | ----------------------------------------------------------------------- |
| Service unit   | .service       | A system service.                                                       |
| Target unit    | .target        | A group of systemd units.                                               |
| Automount unit | .automount     | A file system automount point.                                          |
| Device unit    | .device        | A device file recognized by the kernel.                                 |
| Mount unit     | .mount         | A file system mount point.                                              |
| Path unit      | .path          | A file or directory in a file system.                                   |
| Scope unit     | .scope         | An externally created process.                                          |
| Slice unit     | .slice         | A group of hierarchically organized units that manage system processes. |
| Snapshot unit  | .snapshot      | A saved state of the systemd manager.                                   |
| Socket unit    | .socket        | An inter-process communication socket.                                  |
| Swap unit      | .swap          | A swap device or a swap file.                                           |
| Timer unit     | .timer         | A systemd timer.                                                        |

Don't get confused between **programs**, **processes** and **services** in Linux. Refer to the below table to understand the difference between them:

| Parameters         | Program                                            | Process                                        | Service                                               |
| ------------------ | -------------------------------------------------- | ---------------------------------------------- | ----------------------------------------------------- |
| Initiation         | Executable file launched by users                  | Instance of a program in execution             | Background process providing a specific functionality |
| Execution Location | Can run in foreground or background                | Runs in the foreground or background           | Runs in the background                                |
| User Interaction   | May or may not require user interaction            | Can interact with users through intput/output  | Typically operates without user interaction           |
| Lifespan           | Terminates after execution                         | Starts, executes and terminates                | Runs continuously                                     |
| Autonomy           | Independent of other process                       | Managed by the operating system                | Operates autonomously                                 |
| Functionality      | Provides specific functionality or performs a task | An instance of a program running on the system | Provides a specific service or functionality          |
| System Interaction | Can interact with the system resources             | Interacts with system resources                | May interact with system resources                    |
| Persistence        | N/A                                                | Exist as long as the program is running        | Presists even when not actively used                  |
| Example            | "gcc" - C/C++ compiler                             | "nano" - Text Editor                           | Apache HTTP Server                                    |
