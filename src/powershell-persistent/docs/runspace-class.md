# Runspace Class

## Definition

- Namespace:
    - [System.Management.Automation.Runspaces](system.management.automation.runspaces?view=powershellsdk-7.4.0)

- Assembly:
    - System.Management.Automation.dll

- Package:
    - Microsoft.PowerShell.5.1.ReferenceAssemblies v1.0.0

- Package:
    - System.Management.Automation v7.0.13

- Package:
    - System.Management.Automation v7.1.7

- Package:
    - System.Management.Automation v7.2.12

- Package:
    - System.Management.Automation v7.3.5

- Package:
    - System.Management.Automation v7.4.0

- Package:
    - Microsoft.WSMan.Runtime v6.1.0

- Package:
    - Microsoft.WSMan.Runtime v6.2.0

Public interface to PowerShell Runtime. Provides APIs for creating pipelines, access session state etc.

```cpp
public ref class Runspace abstract : IDisposable
```

```csharp
public abstract class Runspace : IDisposable
```

```fsharp
type Runspace = class
    interface IDisposable
```

```vb
Public MustInherit Class Runspace
Implements IDisposable
```

- Inheritance
    - [Object](/en-us/dotnet/api/system.object)
Runspace

- Implements
    - [IDisposable](/en-us/dotnet/api/system.idisposable)

## Properties

| [ApartmentState](system.management.automation.runspaces.runspace.apartmentstate?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-apartmentstate) | ApartmentState of the thread used to execute commands within this Runspace. |
| --- | --- |
| [CanUseDefaultRunspace](system.management.automation.runspaces.runspace.canusedefaultrunspace?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-canusedefaultrunspace) | Returns true if Runspace.DefaultRunspace can be used to create an instance of the PowerShell class with 'UseCurrentRunspace = true'. |
| [ConnectionInfo](system.management.automation.runspaces.runspace.connectioninfo?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-connectioninfo) | Connection information for remote Runspaces, null for local Runspaces. |
| [Debugger](system.management.automation.runspaces.runspace.debugger?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-debugger) | Gets the debugger. |
| [DefaultRunspace](system.management.automation.runspaces.runspace.defaultrunspace?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-defaultrunspace) | Gets and sets the default Runspace used to evaluate scripts. |
| [DisconnectedOn](system.management.automation.runspaces.runspace.disconnectedon?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-disconnectedon) | DisconnectedOn property applies to remote runspaces that have been disconnected. |
| [Events](system.management.automation.runspaces.runspace.events?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-events) | Gets the event manager. |
| [ExpiresOn](system.management.automation.runspaces.runspace.expireson?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-expireson) | ExpiresOn property applies to remote runspaces that have been disconnected. |
| [Id](system.management.automation.runspaces.runspace.id?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-id) | Gets the Runspace Id. |
| [InitialSessionState](system.management.automation.runspaces.runspace.initialsessionstate?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-initialsessionstate) | InitialSessionState information for this runspace. |
| [InstanceId](system.management.automation.runspaces.runspace.instanceid?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-instanceid) | Get unique id for this instance of runspace. It is primarily used for logging purposes. |
| [JobManager](system.management.automation.runspaces.runspace.jobmanager?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-jobmanager) | Manager for JobSourceAdapters registered in this runspace. |
| [Name](system.management.automation.runspaces.runspace.name?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-name) | Gets and sets a friendly name for the Runspace. |
| [OriginalConnectionInfo](system.management.automation.runspaces.runspace.originalconnectioninfo?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-originalconnectioninfo) | ConnectionInfo originally supplied by the user. |
| [RunspaceAvailability](system.management.automation.runspaces.runspace.runspaceavailability?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-runspaceavailability) | Gets the current availability of the Runspace. |
| [RunspaceConfiguration](system.management.automation.runspaces.runspace.runspaceconfiguration?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-runspaceconfiguration) | RunspaceConfiguration information for this runspace. |
| [RunspaceIsRemote](system.management.automation.runspaces.runspace.runspaceisremote?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-runspaceisremote) | Return whether the Runspace is Remote We can determine this by whether the runspace is an implementation of LocalRunspace or infer it from whether the ConnectionInfo property is null If it happens to be an instance of a LocalRunspace, but has a non-null ConnectionInfo we declare it to be remote. |
| [RunspaceStateInfo](system.management.automation.runspaces.runspace.runspacestateinfo?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-runspacestateinfo) | Retrieve information about current state of the runspace. |
| [SessionStateProxy](system.management.automation.runspaces.runspace.sessionstateproxy?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-sessionstateproxy) | Gets session state proxy. |
| [ThreadOptions](system.management.automation.runspaces.runspace.threadoptions?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-threadoptions) | This property determines whether a new thread is create for each invocation. |
| [Version](system.management.automation.runspaces.runspace.version?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-version) | Return version of this runspace. |

## Methods

| [ClearBaseTransaction()](system.management.automation.runspaces.runspace.clearbasetransaction?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-clearbasetransaction) | Clears the transaction set by SetBaseTransaction() |
| --- | --- |
| [Close()](system.management.automation.runspaces.runspace.close?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-close) | Close the runspace synchronously. |
| [CloseAsync()](system.management.automation.runspaces.runspace.closeasync?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-closeasync) | Close the runspace Asynchronously. |
| [Connect()](system.management.automation.runspaces.runspace.connect?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-connect) | Connects the runspace to its remote counterpart synchronously. |
| [ConnectAsync()](system.management.automation.runspaces.runspace.connectasync?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-connectasync) | Connects a runspace to its remote counterpart asynchronously. |
| [CreateDisconnectedPipeline()](system.management.automation.runspaces.runspace.createdisconnectedpipeline?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-createdisconnectedpipeline) | Creates a PipeLine object in the disconnected state for the currently disconnected remote running command associated with this runspace. |
| [CreateDisconnectedPowerShell()](system.management.automation.runspaces.runspace.createdisconnectedpowershell?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-createdisconnectedpowershell) | Creates a PowerShell object in the disconnected state for the currently disconnected remote running command associated with this runspace. |
| [CreateNestedPipeline()](system.management.automation.runspaces.runspace.createnestedpipeline?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-createnestedpipeline) | Creates a nested pipeline. |
| [CreateNestedPipeline(String, Boolean)](system.management.automation.runspaces.runspace.createnestedpipeline?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-createnestedpipeline%28system-string-system-boolean%29) | Creates a nested pipeline. |
| [CreatePipeline()](system.management.automation.runspaces.runspace.createpipeline?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-createpipeline) | Create an empty pipeline. |
| [CreatePipeline(String, Boolean)](system.management.automation.runspaces.runspace.createpipeline?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-createpipeline%28system-string-system-boolean%29) | Create a pipeline from a command string. |
| [CreatePipeline(String)](system.management.automation.runspaces.runspace.createpipeline?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-createpipeline%28system-string%29) | Creates a pipeline for specified command string. |
| [Disconnect()](system.management.automation.runspaces.runspace.disconnect?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-disconnect) | Disconnects the runspace synchronously. |
| [DisconnectAsync()](system.management.automation.runspaces.runspace.disconnectasync?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-disconnectasync) | Disconnects the runspace asynchronously. |
| [Dispose()](system.management.automation.runspaces.runspace.dispose?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-dispose) | Disposes this runspace instance. Dispose will close the runspace if not closed already. |
| [Dispose(Boolean)](system.management.automation.runspaces.runspace.dispose?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-dispose%28system-boolean%29) | Protected dispose which can be overridden by derived classes. |
| [GetApplicationPrivateData()](system.management.automation.runspaces.runspace.getapplicationprivatedata?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-getapplicationprivatedata) | Private data to be used by applications built on top of PowerShell.<br><br>Local runspace is created with application private data set to an empty [PSPrimitiveDictionary](system.management.automation.psprimitivedictionary?view=powershellsdk-7.4.0).<br><br>Remote runspace gets its application private data from the server (set when creating a remote runspace pool) Calling this method on a remote runspace will block until the data is received from the server. The server will send application private data before reaching [Opened](system.management.automation.runspaces.runspacepoolstate?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspacepoolstate-opened) state.<br><br>Runspaces that are part of a [RunspacePool](system.management.automation.runspaces.runspacepool?view=powershellsdk-7.4.0) inherit application private data from the pool. |
| [GetCapabilities()](system.management.automation.runspaces.runspace.getcapabilities?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-getcapabilities) | Returns Runspace capabilities. |
| [GetRunspace(RunspaceConnectionInfo, Guid, Nullable&lt;Guid&gt;, PSHost, TypeTable)](system.management.automation.runspaces.runspace.getrunspace?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-getrunspace%28system-management-automation-runspaces-runspaceconnectioninfo-system-guid-system-nullable%28%28system-guid%29%29-system-management-automation-host-pshost-system-management-automation-runspaces-typetable%29) | Returns a single disconnected Runspace object targeted to the remote computer and remote session as specified by the connection, session Id, and command Id parameters. |
| [GetRunspaces(RunspaceConnectionInfo, PSHost, TypeTable)](system.management.automation.runspaces.runspace.getrunspaces?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-getrunspaces%28system-management-automation-runspaces-runspaceconnectioninfo-system-management-automation-host-pshost-system-management-automation-runspaces-typetable%29) | Queries the server for disconnected runspaces and creates an array of runspace objects associated with each disconnected runspace on the server. Each runspace object in the returned array is in the Disconnected state and can be connected to the server by calling the Connect() method on the runspace. |
| [GetRunspaces(RunspaceConnectionInfo, PSHost)](system.management.automation.runspaces.runspace.getrunspaces?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-getrunspaces%28system-management-automation-runspaces-runspaceconnectioninfo-system-management-automation-host-pshost%29) | Queries the server for disconnected runspaces and creates an array of runspace objects associated with each disconnected runspace on the server. Each runspace object in the returned array is in the Disconnected state and can be connected to the server by calling the Connect() method on the runspace. |
| [GetRunspaces(RunspaceConnectionInfo)](system.management.automation.runspaces.runspace.getrunspaces?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-getrunspaces%28system-management-automation-runspaces-runspaceconnectioninfo%29) | Queries the server for disconnected runspaces and creates an array of runspace objects associated with each disconnected runspace on the server. Each runspace object in the returned array is in the Disconnected state and can be connected to the server by calling the Connect() method on the runspace. |
| [OnAvailabilityChanged(RunspaceAvailabilityEventArgs)](system.management.automation.runspaces.runspace.onavailabilitychanged?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-onavailabilitychanged%28system-management-automation-runspaces-runspaceavailabilityeventargs%29) | Raises the AvailabilityChanged event. |
| [Open()](system.management.automation.runspaces.runspace.open?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-open) | Opens the runspace synchronously. Runspace must be opened before it can be used. |
| [OpenAsync()](system.management.automation.runspaces.runspace.openasync?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-openasync) | Open the runspace Asynchronously. |
| [ResetRunspaceState()](system.management.automation.runspaces.runspace.resetrunspacestate?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-resetrunspacestate) | Resets the variable table for the runspace to the default state. |
| [SetBaseTransaction(CommittableTransaction, RollbackSeverity)](system.management.automation.runspaces.runspace.setbasetransaction?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-setbasetransaction%28system-transactions-committabletransaction-system-management-automation-rollbackseverity%29) | Sets the base transaction for the runspace; any transactions created on this runspace will be nested to this instance |
| [SetBaseTransaction(CommittableTransaction)](system.management.automation.runspaces.runspace.setbasetransaction?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-setbasetransaction%28system-transactions-committabletransaction%29) | Sets the base transaction for the runspace; any transactions created on this runspace will be nested to this instance |
| [UpdateRunspaceAvailability(RunspaceState, Boolean)](system.management.automation.runspaces.runspace.updaterunspaceavailability?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-updaterunspaceavailability%28system-management-automation-runspaces-runspacestate-system-boolean%29) | Used to update the runspace availability event when the state of the runspace changes. |

## Events

| [AvailabilityChanged](system.management.automation.runspaces.runspace.availabilitychanged?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-availabilitychanged) | Event raised when the availability of the Runspace changes. |
| --- | --- |
| [StateChanged](system.management.automation.runspaces.runspace.statechanged?view=powershellsdk-7.4.0#system-management-automation-runspaces-runspace-statechanged) | Event raised when RunspaceState changes. |

## Applies to
