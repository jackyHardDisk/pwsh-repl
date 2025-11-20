# Microsoft Learn API References

## Core PowerShell Automation APIs

### Runspace APIs

- **Runspace Class
  **: https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.runspaces.runspace
    - Abstract class for PowerShell runtime
    - Provides APIs for creating pipelines, accessing session state
    - Properties: SessionStateProxy, RunspaceStateInfo, RunspaceAvailability

- **RunspaceFactory Class
  **: https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.runspaces.runspacefactory
    - Static factory for creating Runspace objects
    - `CreateRunspace()` - Create default runspace
    - `CreateRunspace(InitialSessionState)` - Create with custom state

- **InitialSessionState Class
  **: https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.runspaces.initialsessionstate
    - Configure runspace at creation time
    - `CreateDefault()` - All PowerShell cmdlets/providers
    - `Create()` - Empty state (NoLanguage mode)
    - Properties: LanguageMode, ExecutionPolicy, Commands, Providers

### PowerShell Execution APIs

- **PowerShell Class
  **: https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.powershell
    - Execute commands and scripts
    - `Create()` - Create new instance
    - `Create(Runspace)` - Attach to existing runspace
    - Methods: AddScript, AddCommand, Invoke, InvokeAsync
    - Properties: Runspace, Commands, Streams, HadErrors

### Stream APIs

- **PipelineResultTypes Enum
  **: https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.runspaces.pipelineresulttypes
    - Defines stream types: Output (1), Error (2), Warning (3), Verbose (4), Debug (5),
      Information (6)

- **PSDataCollection\<T\> Class
  **: https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.psdatacollection-1
    - Thread-safe collection for PowerShell streams
    - Used for: Streams.Error, Streams.Warning, etc.

### Object APIs

- **PSObject Class
  **: https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.psobject
    - Wrapper for .NET objects in PowerShell
    - Properties: BaseObject (unwrapped object)
    - Methods: ToString() - Get string representation

## .NET Channel APIs

### System.Threading.Channels

- **Channel\<T\> Class
  **: https://learn.microsoft.com/en-us/dotnet/core/extensions/channels
    - Thread-safe producer/consumer queue
    - `CreateUnbounded<T>()` - No capacity limit
    - `CreateBounded<T>(capacity)` - Fixed capacity with backpressure
    - Properties: Reader, Writer

- **ChannelReader\<T\>
  **: https://learn.microsoft.com/en-us/dotnet/api/system.threading.channels.channelreader-1
    - Methods: ReadAsync, TryRead, WaitToReadAsync

- **ChannelWriter\<T\>
  **: https://learn.microsoft.com/en-us/dotnet/api/system.threading.channels.channelwriter-1
    - Methods: WriteAsync, TryWrite, Complete

## Async/Await Patterns

### Task-Based Asynchronous Pattern (TAP)

- **TAP Overview
  **: https://learn.microsoft.com/en-us/dotnet/standard/asynchronous-programming-patterns/consuming-the-task-based-asynchronous-pattern
- **Task\<T\> Class
  **: https://learn.microsoft.com/en-us/dotnet/api/system.threading.tasks.task-1
- **Async/Await
  **: https://learn.microsoft.com/en-us/dotnet/csharp/asynchronous-programming/

## PowerShell Cmdlets (for formatting)

### Out-String Cmdlet

- **Out-String Documentation
  **: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/out-string
    - Converts PSObject to string
    - Parameters: -Width (prevent truncation), -Stream (line-by-line)
    - Usage: `Out-String -InputObject $obj -Width 250`

## Error Handling

### RuntimeException

- **System.Management.Automation.RuntimeException
  **: https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.runtimeexception
    - Base class for PowerShell terminating errors
    - Properties: ErrorRecord (detailed error info)

### ErrorRecord

- **ErrorRecord Class
  **: https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.errorrecord
    - Properties: Exception, CategoryInfo, TargetObject, InvocationInfo

## Cross-Platform Considerations

### Platform Detection

- **RuntimeInformation
  **: https://learn.microsoft.com/en-us/dotnet/api/system.runtime.interopservices.runtimeinformation
    - `IsOSPlatform(OSPlatform.Windows)` - Detect Windows
    - Used for ExecutionPolicy (Windows-only)

### ExecutionPolicy

- **ExecutionPolicy Enum
  **: https://learn.microsoft.com/en-us/dotnet/api/microsoft.powershell.executionpolicy
    - Values: Unrestricted, RemoteSigned, AllSigned, Restricted
    - Windows-only feature

## Performance & Threading

### BlockingCollection\<T\> (Alternative to Channel)

- **BlockingCollection
  **: https://learn.microsoft.com/en-us/dotnet/api/system.collections.concurrent.blockingcollection-1
    - Thread-safe blocking collection
    - Less modern than Channel, but still valid

### SemaphoreSlim

- **SemaphoreSlim
  **: https://learn.microsoft.com/en-us/dotnet/api/system.threading.semaphoreslim
    - Lightweight semaphore
    - Methods: Wait, WaitAsync, Release

## Package References

### NuGet Packages

- **System.Management.Automation
  **: https://www.nuget.org/packages/System.Management.Automation
    - Latest: 7.4.0
    - Contains all PowerShell APIs

- **System.Threading.Channels
  **: https://www.nuget.org/packages/System.Threading.Channels
    - Latest: 8.0.0
    - Modern async collections
