# System.Threading.Channels library

The [System.Threading.Channels](/en-us/dotnet/api/system.threading.channels) namespace
provides a set of synchronization data structures for passing data between producers and
consumers asynchronously. The library targets .NET Standard and works on all .NET
implementations.

This library is available in
the [System.Threading.Channels](https://www.nuget.org/packages/System.Threading.Channels)
NuGet package. However, if you're using .NET Core 3.0 or later, the package is included
as part of the framework.

## Producer/consumer conceptual programming model

Channels are an implementation of the producer/consumer conceptual programming model. In
this programming model, producers asynchronously produce data, and consumers
asynchronously consume that data. In other words, this model passes data from one party
to another through a first-in first-out ("FIFO") queue. Think of channels as any other
common generic collection type, such as a `List<T>`. The primary difference is that this
collection manages synchronization and provides various consumption models through
factory creation options. These options control the behavior of the channels, such as
how many elements they're allowed to store and what happens if that limit is reached, or
whether the channel is accessed by multiple producers or multiple consumers
concurrently.

## Bounding strategies

Depending on how a `Channel<T>` is created, its reader and writer behave differently.

To create a channel that specifies a maximum capacity,
call [Channel.CreateBounded](/en-us/dotnet/api/system.threading.channels.channel.createbounded).
To create a channel that is used by any number of readers and writers concurrently,
call [Channel.CreateUnbounded](/en-us/dotnet/api/system.threading.channels.channel.createunbounded).
Each bounding strategy exposes various creator-defined options,
either [BoundedChannelOptions](/en-us/dotnet/api/system.threading.channels.boundedchanneloptions)
or [UnboundedChannelOptions](/en-us/dotnet/api/system.threading.channels.unboundedchanneloptions)
respectively.

Note

Regardless of the bounding strategy, a channel always throws
a [ChannelClosedException](/en-us/dotnet/api/system.threading.channels.channelclosedexception)
when it's used after it's been closed.

### Unbounded channels

To create an unbounded channel, call one of
the [Channel.CreateUnbounded](/en-us/dotnet/api/system.threading.channels.channel.createunbounded)
overloads:

```csharp
var channel = Channel.CreateUnbounded<T>();
```

When you create an unbounded channel, by default, the channel can be used by any number
of readers and writers concurrently. Alternatively, you can specify nondefault behavior
when creating an unbounded channel by providing an `UnboundedChannelOptions` instance.
The channel's capacity is unbounded and all writes are performed synchronously. For more
examples, see Unbounded creation patterns.

### Bounded channels

To create a bounded channel, call one of
the [Channel.CreateBounded](/en-us/dotnet/api/system.threading.channels.channel.createbounded)
overloads:

```csharp
var channel = Channel.CreateBounded<Coordinates>(7);
```

The preceding code creates a channel that has a maximum capacity of `7` items. When you
create a bounded channel, the channel is bound to a maximum capacity. When the bound is
reached, the default behavior is that the channel asynchronously blocks the producer
until space becomes available. You can configure this behavior by specifying an option
when you create the channel. Bounded channels can be created with any capacity value
greater than zero. For other examples, see Bounded creation patterns.

#### Full mode behavior

When using a bounded channel, you can specify the behavior the channel adheres to when
the configured bound is reached. The following table lists the full mode behaviors for
each [BoundedChannelFullMode](/en-us/dotnet/api/system.threading.channels.boundedchannelfullmode)
value:

| Value                                                                                                                                                               | Behavior                                                                                                                                                                  |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [BoundedChannelFullMode.Wait](/en-us/dotnet/api/system.threading.channels.boundedchannelfullmode#system-threading-channels-boundedchannelfullmode-wait)             | This is the default value. Calls to `WriteAsync` wait for space to be available in order to complete the write operation. Calls to `TryWrite` return `false` immediately. |
| [BoundedChannelFullMode.DropNewest](/en-us/dotnet/api/system.threading.channels.boundedchannelfullmode#system-threading-channels-boundedchannelfullmode-dropnewest) | Removes and ignores the newest item in the channel in order to make room for the item being written.                                                                      |
| [BoundedChannelFullMode.DropOldest](/en-us/dotnet/api/system.threading.channels.boundedchannelfullmode#system-threading-channels-boundedchannelfullmode-dropoldest) | Removes and ignores the oldest item in the channel in order to make room for the item being written.                                                                      |
| [BoundedChannelFullMode.DropWrite](/en-us/dotnet/api/system.threading.channels.boundedchannelfullmode#system-threading-channels-boundedchannelfullmode-dropwrite)   | Drops the item being written.                                                                                                                                             |

Important

Whenever
a [Channel&lt;TWrite,TRead&gt;.Writer](/en-us/dotnet/api/system.threading.channels.channel-2.writer)
produces faster than
a [Channel&lt;TWrite,TRead&gt;.Reader](/en-us/dotnet/api/system.threading.channels.channel-2.reader)
can consume, the channel's writer experiences back pressure.

## Producer APIs

The producer functionality is exposed on
the [Channel&lt;TWrite,TRead&gt;.Writer](/en-us/dotnet/api/system.threading.channels.channel-2.writer).
The producer APIs and expected behavior are detailed in the following table:

| API                                                                                                                     | Expected behavior                                                                                                                                                                                                                                                                                                                                                                                          |
|-------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [ChannelWriter&lt;T&gt;.Complete](/en-us/dotnet/api/system.threading.channels.channelwriter-1.complete)                 | Marks the channel as being complete, meaning no more items are written to it.                                                                                                                                                                                                                                                                                                                              |
| [ChannelWriter&lt;T&gt;.TryComplete](/en-us/dotnet/api/system.threading.channels.channelwriter-1.trycomplete)           | Attempts to mark the channel as being completed, meaning no more data is written to it.                                                                                                                                                                                                                                                                                                                    |
| [ChannelWriter&lt;T&gt;.TryWrite](/en-us/dotnet/api/system.threading.channels.channelwriter-1.trywrite)                 | Attempts to write the specified item to the channel. When used with an unbounded channel, this always returns `true` unless the channel's writer signals completion with either [ChannelWriter&lt;T&gt;.Complete](/en-us/dotnet/api/system.threading.channels.channelwriter-1.complete), or [ChannelWriter&lt;T&gt;.TryComplete](/en-us/dotnet/api/system.threading.channels.channelwriter-1.trycomplete). |
| [ChannelWriter&lt;T&gt;.WaitToWriteAsync](/en-us/dotnet/api/system.threading.channels.channelwriter-1.waittowriteasync) | Returns a [ValueTask&lt;TResult&gt;](/en-us/dotnet/api/system.threading.tasks.valuetask-1) that completes when space is available to write an item.                                                                                                                                                                                                                                                        |
| [ChannelWriter&lt;T&gt;.WriteAsync](/en-us/dotnet/api/system.threading.channels.channelwriter-1.writeasync)             | Asynchronously writes an item to the channel.                                                                                                                                                                                                                                                                                                                                                              |

## Consumer APIs

The consumer functionality is exposed on
the [Channel&lt;TWrite,TRead&gt;.Reader](/en-us/dotnet/api/system.threading.channels.channel-2.reader).
The consumer APIs and expected behavior are detailed in the following table:

| API                                                                                                                   | Expected behavior                                                                                                                                              |
|-----------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [ChannelReader&lt;T&gt;.ReadAllAsync](/en-us/dotnet/api/system.threading.channels.channelreader-1.readallasync)       | Creates an [IAsyncEnumerable&lt;T&gt;](/en-us/dotnet/api/system.collections.generic.iasyncenumerable-1) that enables reading all of the data from the channel. |
| [ChannelReader&lt;T&gt;.ReadAsync](/en-us/dotnet/api/system.threading.channels.channelreader-1.readasync)             | Asynchronously reads an item from the channel.                                                                                                                 |
| [ChannelReader&lt;T&gt;.TryPeek](/en-us/dotnet/api/system.threading.channels.channelreader-1.trypeek)                 | Attempts to peek at an item from the channel.                                                                                                                  |
| [ChannelReader&lt;T&gt;.TryRead](/en-us/dotnet/api/system.threading.channels.channelreader-1.tryread)                 | Attempts to read an item from the channel.                                                                                                                     |
| [ChannelReader&lt;T&gt;.WaitToReadAsync](/en-us/dotnet/api/system.threading.channels.channelreader-1.waittoreadasync) | Returns a [ValueTask&lt;TResult&gt;](/en-us/dotnet/api/system.threading.tasks.valuetask-1) that completes when data is available to read.                      |

## Common usage patterns

There are several usage patterns for channels. The API is designed to be simple,
consistent, and as flexible as possible. All of the asynchronous methods return a
`ValueTask` (or `ValueTask<bool>`) that represents a lightweight asynchronous operation
that can avoid allocating if the operation completes synchronously and potentially even
asynchronously. Additionally, the API is designed to be composable, in that the creator
of a channel makes promises about its intended usage. When a channel is created with
certain parameters, the internal implementation can operate more efficiently knowing
these promises.

### Creation patterns

Imagine that you're creating a producer/consumer solution for a global position system (
GPS). You want to track the coordinates of a device over time. A sample coordinates
object might look like this:

```csharp
/// <summary>
/// A representation of a device's coordinates,
/// which includes latitude and longitude.
/// </summary>
/// <param name="DeviceId">A unique device identifier.</param>
/// <param name="Latitude">The latitude of the device.</param>
/// <param name="Longitude">The longitude of the device.</param>
public readonly record struct Coordinates(
    Guid DeviceId,
    double Latitude,
    double Longitude);
```

#### Unbounded creation patterns

One common usage pattern is to create a default unbounded channel:

```csharp
var channel = Channel.CreateUnbounded<Coordinates>();
```

But instead, let's imagine that you want to create an unbounded channel with multiple
producers and consumers:

```csharp
var channel = Channel.CreateUnbounded<Coordinates>(
    new UnboundedChannelOptions
    {
        SingleWriter = false,
        SingleReader = false,
        AllowSynchronousContinuations = true
    });
```

In this case, all writes are synchronous, even the `WriteAsync`. This is because an
unbounded channel always has available room for a write effectively immediately.
However, with `AllowSynchronousContinuations` set to `true`, the writes may end up doing
work associated with a reader by executing their continuations. This doesn't affect the
synchronicity of the operation.

#### Bounded creation patterns

With bounded channels, the configurability of the channel should be known to the
consumer to help ensure proper consumption. That is, the consumer should know what
behavior the channel exhibits when the configured bound is reached. Let's explore some
of the common bounded creation patterns.

The simplest way to create a bounded channel is to specify a capacity:

```csharp
var channel = Channel.CreateBounded<Coordinates>(1);
```

The preceding code creates a bounded channel with a max capacity of `1`. Other options
are available, some options are the same as an unbounded channel, while others are
specific to unbounded channels:

```csharp
var channel = Channel.CreateBounded<Coordinates>(
    new BoundedChannelOptions(1_000)
    {
        SingleWriter = true,
        SingleReader = false,
        AllowSynchronousContinuations = false,
        FullMode = BoundedChannelFullMode.DropWrite
    });
```

In the preceding code, the channel is created as a bounded channel that's limited to
1,000 items, with a single writer but many readers. Its full mode behavior is defined as
`DropWrite`, which means that it drops the item being written if the channel is full.

To observe items that are dropped when using bounded channels, register an `itemDropped`
callback:

```csharp
var channel = Channel.CreateBounded(
    new BoundedChannelOptions(10)
    {
        AllowSynchronousContinuations = true,
        FullMode = BoundedChannelFullMode.DropOldest
    },
    static void (Coordinates dropped) =>
        Console.WriteLine($"Coordinates dropped: {dropped}"));
```

Whenever the channel is full and a new item is added, the `itemDropped` callback is
invoked. In this example, the provided callback writes the item to the console, but
you're free to take any other action you want.

### Producer patterns

Imagine that the producer in this scenario is writing new coordinates to the channel.
The producer can do this by
calling [TryWrite](/en-us/dotnet/api/system.threading.channels.channelwriter-1.trywrite):

```csharp
static void ProduceWithWhileAndTryWrite(
    ChannelWriter<Coordinates> writer, Coordinates coordinates)
{
    while (coordinates is { Latitude: < 90, Longitude: < 180 })
    {
        var tempCoordinates = coordinates with
        {
            Latitude = coordinates.Latitude + .5,
            Longitude = coordinates.Longitude + 1
        };

        if (writer.TryWrite(item: tempCoordinates))
        {
            coordinates = tempCoordinates;
        }
    }
}
```

The preceding producer code:

- Accepts the `Channel<Coordinates>.Writer` (`ChannelWriter<Coordinates>`) as an
  argument, along with the initial `Coordinates`.
- Defines a conditional `while` loop that attempts to move the coordinates using
  `TryWrite`.

An alternative producer might use the `WriteAsync` method:

```csharp
static async ValueTask ProduceWithWhileWriteAsync(
    ChannelWriter<Coordinates> writer, Coordinates coordinates)
{
    while (coordinates is { Latitude: < 90, Longitude: < 180 })
    {
        await writer.WriteAsync(
            item: coordinates = coordinates with
            {
                Latitude = coordinates.Latitude + .5,
                Longitude = coordinates.Longitude + 1
            });
    }

    writer.Complete();
}
```

Again, the `Channel<Coordinates>.Writer` is used within a `while` loop. But this time,
the [WriteAsync](/en-us/dotnet/api/system.threading.channels.channelwriter-1.writeasync)
method is called. The method continues only after the coordinates have been written.
When the `while` loop exits, a call
to [Complete](/en-us/dotnet/api/system.threading.channels.channelwriter-1.complete) is
made, which signals that no more data is written to the channel.

Another producer pattern is to use
the [WaitToWriteAsync](/en-us/dotnet/api/system.threading.channels.channelwriter-1.waittowriteasync)
method, consider the following code:

```csharp
static async ValueTask ProduceWithWaitToWriteAsync(
    ChannelWriter<Coordinates> writer, Coordinates coordinates)
{
    while (coordinates is { Latitude: < 90, Longitude: < 180 } &&
        await writer.WaitToWriteAsync())
    {
        var tempCoordinates = coordinates with
        {
            Latitude = coordinates.Latitude + .5,
            Longitude = coordinates.Longitude + 1
        };

        if (writer.TryWrite(item: tempCoordinates))
        {
            coordinates = tempCoordinates;
        }

        await Task.Delay(TimeSpan.FromMilliseconds(10));
    }

    writer.Complete();
}
```

As part of the conditional `while`, the result of the `WaitToWriteAsync` call is used to
determine whether to continue the loop.

### Consumer patterns

There are several common channel consumer patterns. When a channel is never ending,
meaning it produces data indefinitely, the consumer could use a `while (true)` loop, and
read data as it becomes available:

```csharp
static async ValueTask ConsumeWithWhileAsync(
    ChannelReader<Coordinates> reader)
{
    while (true)
    {
        // May throw ChannelClosedException if
        // the parent channel's writer signals complete.
        Coordinates coordinates = await reader.ReadAsync();
        Console.WriteLine(coordinates);
    }
}
```

Note

This code throws an exception if the channel is closed.

An alternative consumer could avoid this concern by using a nested while loop, as shown
in the following code:

```csharp
static async ValueTask ConsumeWithNestedWhileAsync(
    ChannelReader<Coordinates> reader)
{
    while (await reader.WaitToReadAsync())
    {
        while (reader.TryRead(out Coordinates coordinates))
        {
            Console.WriteLine(coordinates);
        }
    }
}
```

In the preceding code, the consumer waits to read data. Once the data is available, the
consumer tries to read it. These loops continue to evaluate until the producer of the
channel signals that it no longer has data to be read. With that said, when a producer
is known to have a finite number of items it produces and it signals completion, the
consumer can use `await foreach` semantics to iterate over the items:

```csharp
static async ValueTask ConsumeWithAwaitForeachAsync(
    ChannelReader<Coordinates> reader)
{
    await foreach (Coordinates coordinates in reader.ReadAllAsync())
    {
        Console.WriteLine(coordinates);
    }
}
```

The preceding code uses
the [ReadAllAsync](/en-us/dotnet/api/system.threading.channels.channelreader-1.readallasync)
method to read all of the coordinates from the channel.
