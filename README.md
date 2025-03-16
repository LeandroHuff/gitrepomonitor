# Git Repository Monitor

Is a service daemon to monitor repository git status and proceed with commits to make the repository up to date.


# Service Daemons

Systemd is a suite of system management daemons, libraries, and utilities designed to centralize the management of various aspects of a Linux OS.

It provides a standard process for controlling what programs run when a Linux OS boots up and during its operation.

Systemd service file is a plain text file with the ‘.service’ extension contains configuration directives for a service.

These directives define how a service should be started, stopped, and managed. Let's break down the key sections of a Systemd service file:


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
service [Script] [Action] [Option]

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


• start: Starts the script.
• stop: Stops the script.
• status: Shows the current status of the script.
• restart: Ensures that the script is restarted.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sudo service command/script start
sudo service command/script stop
sudo service command/script restart
sudo service command/script status
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


Unit Section:

The `[Unit]` section provides metadata about the service. It includes the `Description`, which is a brief description of the service, and other optional fields like `After` to specify service dependencies.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
[Unit]
 Description=My Custom Service
 After=network.target
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Service Section:

The `[Service]` section contains directives related to how the service should be executed. The most important directive is `ExecStart`, which specifies the command or script to run as the service.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
[Service]
 ExecStart=/path/to/your/command
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


Additional directives can set the working directory, user, group, and configure restart behavior:


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
WorkingDirectory=/path/to/your/working/directory
 User=your_username
 Group=your_group_name
 Restart=always
 RestartSec=3
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


Install Section:

The `[Install]` section specifies when and how the service should be started or enabled. The `WantedBy` directive determines the target at which the service should start, such as `multi-user.target` for services that run after boot.


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
[Install]
 WantedBy=multi-user.target
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



Writing a Systemd Service File

Now that we understand the structure, let’s create a simple Systemd service file. Imagine we want to run a custom script located at `/opt/my_script.sh` as a background service.

Create the Service File


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sudo nano /etc/systemd/system/my_custom_service.service
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


Write the Service File


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


Adjust the paths, user, and other settings to match your specific use case.

Save and Reload Systemd

Save the file and exit the text editor. Then, reload Systemd to read the new service file:


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sudo systemctl daemon-reload
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


Start and Enable the Service

You can now start and enable your service:


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sudo systemctl start my_custom_service
sudo systemctl enable my_custom_service
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Replace `my_custom_service` with the actual service name.

Check the Service Status

Verify that your service is running without errors


~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sudo systemctl status my_custom_service
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



Managing Systemd Services

Systemd provides a set of commands to manage services, such as

- `systemctl start service_name`: Start a service.
- `systemctl stop service_name`: Stop a service.
- `systemctl restart service_name`: Restart a service.
- `systemctl status service_name`: Display the status of a service.
- `systemctl enable service_name`: Enable a service to start at boot.
- `systemctl disable service_name`: Disable a service from starting at boot.

