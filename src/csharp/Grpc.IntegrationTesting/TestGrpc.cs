// Generated by the protocol buffer compiler.  DO NOT EDIT!
// source: src/proto/grpc/testing/test.proto
// Original file comments:
// Copyright 2015-2016, Google Inc.
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//     * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//     * Neither the name of Google Inc. nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// An integration test service that covers all the method signature permutations
// of unary/streaming requests/responses.
//
#region Designer generated code

using System;
using System.Threading;
using System.Threading.Tasks;
using Grpc.Core;

namespace Grpc.Testing {
  /// <summary>
  ///  A simple service to test the various types of RPCs and experiment with
  ///  performance with various types of payload.
  /// </summary>
  public static class TestService
  {
    static readonly string __ServiceName = "grpc.testing.TestService";

    static readonly Marshaller<global::Grpc.Testing.Empty> __Marshaller_Empty = Marshallers.Create((arg) => global::Google.Protobuf.MessageExtensions.ToByteArray(arg), global::Grpc.Testing.Empty.Parser.ParseFrom);
    static readonly Marshaller<global::Grpc.Testing.SimpleRequest> __Marshaller_SimpleRequest = Marshallers.Create((arg) => global::Google.Protobuf.MessageExtensions.ToByteArray(arg), global::Grpc.Testing.SimpleRequest.Parser.ParseFrom);
    static readonly Marshaller<global::Grpc.Testing.SimpleResponse> __Marshaller_SimpleResponse = Marshallers.Create((arg) => global::Google.Protobuf.MessageExtensions.ToByteArray(arg), global::Grpc.Testing.SimpleResponse.Parser.ParseFrom);
    static readonly Marshaller<global::Grpc.Testing.StreamingOutputCallRequest> __Marshaller_StreamingOutputCallRequest = Marshallers.Create((arg) => global::Google.Protobuf.MessageExtensions.ToByteArray(arg), global::Grpc.Testing.StreamingOutputCallRequest.Parser.ParseFrom);
    static readonly Marshaller<global::Grpc.Testing.StreamingOutputCallResponse> __Marshaller_StreamingOutputCallResponse = Marshallers.Create((arg) => global::Google.Protobuf.MessageExtensions.ToByteArray(arg), global::Grpc.Testing.StreamingOutputCallResponse.Parser.ParseFrom);
    static readonly Marshaller<global::Grpc.Testing.StreamingInputCallRequest> __Marshaller_StreamingInputCallRequest = Marshallers.Create((arg) => global::Google.Protobuf.MessageExtensions.ToByteArray(arg), global::Grpc.Testing.StreamingInputCallRequest.Parser.ParseFrom);
    static readonly Marshaller<global::Grpc.Testing.StreamingInputCallResponse> __Marshaller_StreamingInputCallResponse = Marshallers.Create((arg) => global::Google.Protobuf.MessageExtensions.ToByteArray(arg), global::Grpc.Testing.StreamingInputCallResponse.Parser.ParseFrom);

    static readonly Method<global::Grpc.Testing.Empty, global::Grpc.Testing.Empty> __Method_EmptyCall = new Method<global::Grpc.Testing.Empty, global::Grpc.Testing.Empty>(
        MethodType.Unary,
        __ServiceName,
        "EmptyCall",
        __Marshaller_Empty,
        __Marshaller_Empty);

    static readonly Method<global::Grpc.Testing.SimpleRequest, global::Grpc.Testing.SimpleResponse> __Method_UnaryCall = new Method<global::Grpc.Testing.SimpleRequest, global::Grpc.Testing.SimpleResponse>(
        MethodType.Unary,
        __ServiceName,
        "UnaryCall",
        __Marshaller_SimpleRequest,
        __Marshaller_SimpleResponse);

    static readonly Method<global::Grpc.Testing.StreamingOutputCallRequest, global::Grpc.Testing.StreamingOutputCallResponse> __Method_StreamingOutputCall = new Method<global::Grpc.Testing.StreamingOutputCallRequest, global::Grpc.Testing.StreamingOutputCallResponse>(
        MethodType.ServerStreaming,
        __ServiceName,
        "StreamingOutputCall",
        __Marshaller_StreamingOutputCallRequest,
        __Marshaller_StreamingOutputCallResponse);

    static readonly Method<global::Grpc.Testing.StreamingInputCallRequest, global::Grpc.Testing.StreamingInputCallResponse> __Method_StreamingInputCall = new Method<global::Grpc.Testing.StreamingInputCallRequest, global::Grpc.Testing.StreamingInputCallResponse>(
        MethodType.ClientStreaming,
        __ServiceName,
        "StreamingInputCall",
        __Marshaller_StreamingInputCallRequest,
        __Marshaller_StreamingInputCallResponse);

    static readonly Method<global::Grpc.Testing.StreamingOutputCallRequest, global::Grpc.Testing.StreamingOutputCallResponse> __Method_FullDuplexCall = new Method<global::Grpc.Testing.StreamingOutputCallRequest, global::Grpc.Testing.StreamingOutputCallResponse>(
        MethodType.DuplexStreaming,
        __ServiceName,
        "FullDuplexCall",
        __Marshaller_StreamingOutputCallRequest,
        __Marshaller_StreamingOutputCallResponse);

    static readonly Method<global::Grpc.Testing.StreamingOutputCallRequest, global::Grpc.Testing.StreamingOutputCallResponse> __Method_HalfDuplexCall = new Method<global::Grpc.Testing.StreamingOutputCallRequest, global::Grpc.Testing.StreamingOutputCallResponse>(
        MethodType.DuplexStreaming,
        __ServiceName,
        "HalfDuplexCall",
        __Marshaller_StreamingOutputCallRequest,
        __Marshaller_StreamingOutputCallResponse);

    /// <summary>Service descriptor</summary>
    public static global::Google.Protobuf.Reflection.ServiceDescriptor Descriptor
    {
      get { return global::Grpc.Testing.TestReflection.Descriptor.Services[0]; }
    }

    /// <summary>Base class for server-side implementations of TestService</summary>
    public abstract class TestServiceBase
    {
      /// <summary>
      ///  One empty request followed by one empty response.
      /// </summary>
      public virtual global::System.Threading.Tasks.Task<global::Grpc.Testing.Empty> EmptyCall(global::Grpc.Testing.Empty request, ServerCallContext context)
      {
        throw new RpcException(new Status(StatusCode.Unimplemented, ""));
      }

      /// <summary>
      ///  One request followed by one response.
      /// </summary>
      public virtual global::System.Threading.Tasks.Task<global::Grpc.Testing.SimpleResponse> UnaryCall(global::Grpc.Testing.SimpleRequest request, ServerCallContext context)
      {
        throw new RpcException(new Status(StatusCode.Unimplemented, ""));
      }

      /// <summary>
      ///  One request followed by a sequence of responses (streamed download).
      ///  The server returns the payload with client desired type and sizes.
      /// </summary>
      public virtual global::System.Threading.Tasks.Task StreamingOutputCall(global::Grpc.Testing.StreamingOutputCallRequest request, IServerStreamWriter<global::Grpc.Testing.StreamingOutputCallResponse> responseStream, ServerCallContext context)
      {
        throw new RpcException(new Status(StatusCode.Unimplemented, ""));
      }

      /// <summary>
      ///  A sequence of requests followed by one response (streamed upload).
      ///  The server returns the aggregated size of client payload as the result.
      /// </summary>
      public virtual global::System.Threading.Tasks.Task<global::Grpc.Testing.StreamingInputCallResponse> StreamingInputCall(IAsyncStreamReader<global::Grpc.Testing.StreamingInputCallRequest> requestStream, ServerCallContext context)
      {
        throw new RpcException(new Status(StatusCode.Unimplemented, ""));
      }

      /// <summary>
      ///  A sequence of requests with each request served by the server immediately.
      ///  As one request could lead to multiple responses, this interface
      ///  demonstrates the idea of full duplexing.
      /// </summary>
      public virtual global::System.Threading.Tasks.Task FullDuplexCall(IAsyncStreamReader<global::Grpc.Testing.StreamingOutputCallRequest> requestStream, IServerStreamWriter<global::Grpc.Testing.StreamingOutputCallResponse> responseStream, ServerCallContext context)
      {
        throw new RpcException(new Status(StatusCode.Unimplemented, ""));
      }

      /// <summary>
      ///  A sequence of requests followed by a sequence of responses.
      ///  The server buffers all the client requests and then serves them in order. A
      ///  stream of responses are returned to the client when the server starts with
      ///  first request.
      /// </summary>
      public virtual global::System.Threading.Tasks.Task HalfDuplexCall(IAsyncStreamReader<global::Grpc.Testing.StreamingOutputCallRequest> requestStream, IServerStreamWriter<global::Grpc.Testing.StreamingOutputCallResponse> responseStream, ServerCallContext context)
      {
        throw new RpcException(new Status(StatusCode.Unimplemented, ""));
      }

    }

    /// <summary>Client for TestService</summary>
    public class TestServiceClient : ClientBase<TestServiceClient>
    {
      /// <summary>Creates a new client for TestService</summary>
      /// <param name="channel">The channel to use to make remote calls.</param>
      public TestServiceClient(Channel channel) : base(channel)
      {
      }
      /// <summary>Creates a new client for TestService that uses a custom <c>CallInvoker</c>.</summary>
      /// <param name="callInvoker">The callInvoker to use to make remote calls.</param>
      public TestServiceClient(CallInvoker callInvoker) : base(callInvoker)
      {
      }
      /// <summary>Protected parameterless constructor to allow creation of test doubles.</summary>
      protected TestServiceClient() : base()
      {
      }
      /// <summary>Protected constructor to allow creation of configured clients.</summary>
      /// <param name="configuration">The client configuration.</param>
      protected TestServiceClient(ClientBaseConfiguration configuration) : base(configuration)
      {
      }

      /// <summary>
      ///  One empty request followed by one empty response.
      /// </summary>
      public virtual global::Grpc.Testing.Empty EmptyCall(global::Grpc.Testing.Empty request, Metadata headers = null, DateTime? deadline = null, CancellationToken cancellationToken = default(CancellationToken))
      {
        return EmptyCall(request, new CallOptions(headers, deadline, cancellationToken));
      }
      /// <summary>
      ///  One empty request followed by one empty response.
      /// </summary>
      public virtual global::Grpc.Testing.Empty EmptyCall(global::Grpc.Testing.Empty request, CallOptions options)
      {
        return CallInvoker.BlockingUnaryCall(__Method_EmptyCall, null, options, request);
      }
      /// <summary>
      ///  One empty request followed by one empty response.
      /// </summary>
      public virtual AsyncUnaryCall<global::Grpc.Testing.Empty> EmptyCallAsync(global::Grpc.Testing.Empty request, Metadata headers = null, DateTime? deadline = null, CancellationToken cancellationToken = default(CancellationToken))
      {
        return EmptyCallAsync(request, new CallOptions(headers, deadline, cancellationToken));
      }
      /// <summary>
      ///  One empty request followed by one empty response.
      /// </summary>
      public virtual AsyncUnaryCall<global::Grpc.Testing.Empty> EmptyCallAsync(global::Grpc.Testing.Empty request, CallOptions options)
      {
        return CallInvoker.AsyncUnaryCall(__Method_EmptyCall, null, options, request);
      }
      /// <summary>
      ///  One request followed by one response.
      /// </summary>
      public virtual global::Grpc.Testing.SimpleResponse UnaryCall(global::Grpc.Testing.SimpleRequest request, Metadata headers = null, DateTime? deadline = null, CancellationToken cancellationToken = default(CancellationToken))
      {
        return UnaryCall(request, new CallOptions(headers, deadline, cancellationToken));
      }
      /// <summary>
      ///  One request followed by one response.
      /// </summary>
      public virtual global::Grpc.Testing.SimpleResponse UnaryCall(global::Grpc.Testing.SimpleRequest request, CallOptions options)
      {
        return CallInvoker.BlockingUnaryCall(__Method_UnaryCall, null, options, request);
      }
      /// <summary>
      ///  One request followed by one response.
      /// </summary>
      public virtual AsyncUnaryCall<global::Grpc.Testing.SimpleResponse> UnaryCallAsync(global::Grpc.Testing.SimpleRequest request, Metadata headers = null, DateTime? deadline = null, CancellationToken cancellationToken = default(CancellationToken))
      {
        return UnaryCallAsync(request, new CallOptions(headers, deadline, cancellationToken));
      }
      /// <summary>
      ///  One request followed by one response.
      /// </summary>
      public virtual AsyncUnaryCall<global::Grpc.Testing.SimpleResponse> UnaryCallAsync(global::Grpc.Testing.SimpleRequest request, CallOptions options)
      {
        return CallInvoker.AsyncUnaryCall(__Method_UnaryCall, null, options, request);
      }
      /// <summary>
      ///  One request followed by a sequence of responses (streamed download).
      ///  The server returns the payload with client desired type and sizes.
      /// </summary>
      public virtual AsyncServerStreamingCall<global::Grpc.Testing.StreamingOutputCallResponse> StreamingOutputCall(global::Grpc.Testing.StreamingOutputCallRequest request, Metadata headers = null, DateTime? deadline = null, CancellationToken cancellationToken = default(CancellationToken))
      {
        return StreamingOutputCall(request, new CallOptions(headers, deadline, cancellationToken));
      }
      /// <summary>
      ///  One request followed by a sequence of responses (streamed download).
      ///  The server returns the payload with client desired type and sizes.
      /// </summary>
      public virtual AsyncServerStreamingCall<global::Grpc.Testing.StreamingOutputCallResponse> StreamingOutputCall(global::Grpc.Testing.StreamingOutputCallRequest request, CallOptions options)
      {
        return CallInvoker.AsyncServerStreamingCall(__Method_StreamingOutputCall, null, options, request);
      }
      /// <summary>
      ///  A sequence of requests followed by one response (streamed upload).
      ///  The server returns the aggregated size of client payload as the result.
      /// </summary>
      public virtual AsyncClientStreamingCall<global::Grpc.Testing.StreamingInputCallRequest, global::Grpc.Testing.StreamingInputCallResponse> StreamingInputCall(Metadata headers = null, DateTime? deadline = null, CancellationToken cancellationToken = default(CancellationToken))
      {
        return StreamingInputCall(new CallOptions(headers, deadline, cancellationToken));
      }
      /// <summary>
      ///  A sequence of requests followed by one response (streamed upload).
      ///  The server returns the aggregated size of client payload as the result.
      /// </summary>
      public virtual AsyncClientStreamingCall<global::Grpc.Testing.StreamingInputCallRequest, global::Grpc.Testing.StreamingInputCallResponse> StreamingInputCall(CallOptions options)
      {
        return CallInvoker.AsyncClientStreamingCall(__Method_StreamingInputCall, null, options);
      }
      /// <summary>
      ///  A sequence of requests with each request served by the server immediately.
      ///  As one request could lead to multiple responses, this interface
      ///  demonstrates the idea of full duplexing.
      /// </summary>
      public virtual AsyncDuplexStreamingCall<global::Grpc.Testing.StreamingOutputCallRequest, global::Grpc.Testing.StreamingOutputCallResponse> FullDuplexCall(Metadata headers = null, DateTime? deadline = null, CancellationToken cancellationToken = default(CancellationToken))
      {
        return FullDuplexCall(new CallOptions(headers, deadline, cancellationToken));
      }
      /// <summary>
      ///  A sequence of requests with each request served by the server immediately.
      ///  As one request could lead to multiple responses, this interface
      ///  demonstrates the idea of full duplexing.
      /// </summary>
      public virtual AsyncDuplexStreamingCall<global::Grpc.Testing.StreamingOutputCallRequest, global::Grpc.Testing.StreamingOutputCallResponse> FullDuplexCall(CallOptions options)
      {
        return CallInvoker.AsyncDuplexStreamingCall(__Method_FullDuplexCall, null, options);
      }
      /// <summary>
      ///  A sequence of requests followed by a sequence of responses.
      ///  The server buffers all the client requests and then serves them in order. A
      ///  stream of responses are returned to the client when the server starts with
      ///  first request.
      /// </summary>
      public virtual AsyncDuplexStreamingCall<global::Grpc.Testing.StreamingOutputCallRequest, global::Grpc.Testing.StreamingOutputCallResponse> HalfDuplexCall(Metadata headers = null, DateTime? deadline = null, CancellationToken cancellationToken = default(CancellationToken))
      {
        return HalfDuplexCall(new CallOptions(headers, deadline, cancellationToken));
      }
      /// <summary>
      ///  A sequence of requests followed by a sequence of responses.
      ///  The server buffers all the client requests and then serves them in order. A
      ///  stream of responses are returned to the client when the server starts with
      ///  first request.
      /// </summary>
      public virtual AsyncDuplexStreamingCall<global::Grpc.Testing.StreamingOutputCallRequest, global::Grpc.Testing.StreamingOutputCallResponse> HalfDuplexCall(CallOptions options)
      {
        return CallInvoker.AsyncDuplexStreamingCall(__Method_HalfDuplexCall, null, options);
      }
      /// <summary>Creates a new instance of client from given <c>ClientBaseConfiguration</c>.</summary>
      protected override TestServiceClient NewInstance(ClientBaseConfiguration configuration)
      {
        return new TestServiceClient(configuration);
      }
    }

    /// <summary>Creates service definition that can be registered with a server</summary>
    public static ServerServiceDefinition BindService(TestServiceBase serviceImpl)
    {
      return ServerServiceDefinition.CreateBuilder()
          .AddMethod(__Method_EmptyCall, serviceImpl.EmptyCall)
          .AddMethod(__Method_UnaryCall, serviceImpl.UnaryCall)
          .AddMethod(__Method_StreamingOutputCall, serviceImpl.StreamingOutputCall)
          .AddMethod(__Method_StreamingInputCall, serviceImpl.StreamingInputCall)
          .AddMethod(__Method_FullDuplexCall, serviceImpl.FullDuplexCall)
          .AddMethod(__Method_HalfDuplexCall, serviceImpl.HalfDuplexCall).Build();
    }

  }
  /// <summary>
  ///  A simple service NOT implemented at servers so clients can test for
  ///  that case.
  /// </summary>
  public static class UnimplementedService
  {
    static readonly string __ServiceName = "grpc.testing.UnimplementedService";

    static readonly Marshaller<global::Grpc.Testing.Empty> __Marshaller_Empty = Marshallers.Create((arg) => global::Google.Protobuf.MessageExtensions.ToByteArray(arg), global::Grpc.Testing.Empty.Parser.ParseFrom);

    static readonly Method<global::Grpc.Testing.Empty, global::Grpc.Testing.Empty> __Method_UnimplementedCall = new Method<global::Grpc.Testing.Empty, global::Grpc.Testing.Empty>(
        MethodType.Unary,
        __ServiceName,
        "UnimplementedCall",
        __Marshaller_Empty,
        __Marshaller_Empty);

    /// <summary>Service descriptor</summary>
    public static global::Google.Protobuf.Reflection.ServiceDescriptor Descriptor
    {
      get { return global::Grpc.Testing.TestReflection.Descriptor.Services[1]; }
    }

    /// <summary>Base class for server-side implementations of UnimplementedService</summary>
    public abstract class UnimplementedServiceBase
    {
      /// <summary>
      ///  A call that no server should implement
      /// </summary>
      public virtual global::System.Threading.Tasks.Task<global::Grpc.Testing.Empty> UnimplementedCall(global::Grpc.Testing.Empty request, ServerCallContext context)
      {
        throw new RpcException(new Status(StatusCode.Unimplemented, ""));
      }

    }

    /// <summary>Client for UnimplementedService</summary>
    public class UnimplementedServiceClient : ClientBase<UnimplementedServiceClient>
    {
      /// <summary>Creates a new client for UnimplementedService</summary>
      /// <param name="channel">The channel to use to make remote calls.</param>
      public UnimplementedServiceClient(Channel channel) : base(channel)
      {
      }
      /// <summary>Creates a new client for UnimplementedService that uses a custom <c>CallInvoker</c>.</summary>
      /// <param name="callInvoker">The callInvoker to use to make remote calls.</param>
      public UnimplementedServiceClient(CallInvoker callInvoker) : base(callInvoker)
      {
      }
      /// <summary>Protected parameterless constructor to allow creation of test doubles.</summary>
      protected UnimplementedServiceClient() : base()
      {
      }
      /// <summary>Protected constructor to allow creation of configured clients.</summary>
      /// <param name="configuration">The client configuration.</param>
      protected UnimplementedServiceClient(ClientBaseConfiguration configuration) : base(configuration)
      {
      }

      /// <summary>
      ///  A call that no server should implement
      /// </summary>
      public virtual global::Grpc.Testing.Empty UnimplementedCall(global::Grpc.Testing.Empty request, Metadata headers = null, DateTime? deadline = null, CancellationToken cancellationToken = default(CancellationToken))
      {
        return UnimplementedCall(request, new CallOptions(headers, deadline, cancellationToken));
      }
      /// <summary>
      ///  A call that no server should implement
      /// </summary>
      public virtual global::Grpc.Testing.Empty UnimplementedCall(global::Grpc.Testing.Empty request, CallOptions options)
      {
        return CallInvoker.BlockingUnaryCall(__Method_UnimplementedCall, null, options, request);
      }
      /// <summary>
      ///  A call that no server should implement
      /// </summary>
      public virtual AsyncUnaryCall<global::Grpc.Testing.Empty> UnimplementedCallAsync(global::Grpc.Testing.Empty request, Metadata headers = null, DateTime? deadline = null, CancellationToken cancellationToken = default(CancellationToken))
      {
        return UnimplementedCallAsync(request, new CallOptions(headers, deadline, cancellationToken));
      }
      /// <summary>
      ///  A call that no server should implement
      /// </summary>
      public virtual AsyncUnaryCall<global::Grpc.Testing.Empty> UnimplementedCallAsync(global::Grpc.Testing.Empty request, CallOptions options)
      {
        return CallInvoker.AsyncUnaryCall(__Method_UnimplementedCall, null, options, request);
      }
      /// <summary>Creates a new instance of client from given <c>ClientBaseConfiguration</c>.</summary>
      protected override UnimplementedServiceClient NewInstance(ClientBaseConfiguration configuration)
      {
        return new UnimplementedServiceClient(configuration);
      }
    }

    /// <summary>Creates service definition that can be registered with a server</summary>
    public static ServerServiceDefinition BindService(UnimplementedServiceBase serviceImpl)
    {
      return ServerServiceDefinition.CreateBuilder()
          .AddMethod(__Method_UnimplementedCall, serviceImpl.UnimplementedCall).Build();
    }

  }
  /// <summary>
  ///  A service used to control reconnect server.
  /// </summary>
  public static class ReconnectService
  {
    static readonly string __ServiceName = "grpc.testing.ReconnectService";

    static readonly Marshaller<global::Grpc.Testing.ReconnectParams> __Marshaller_ReconnectParams = Marshallers.Create((arg) => global::Google.Protobuf.MessageExtensions.ToByteArray(arg), global::Grpc.Testing.ReconnectParams.Parser.ParseFrom);
    static readonly Marshaller<global::Grpc.Testing.Empty> __Marshaller_Empty = Marshallers.Create((arg) => global::Google.Protobuf.MessageExtensions.ToByteArray(arg), global::Grpc.Testing.Empty.Parser.ParseFrom);
    static readonly Marshaller<global::Grpc.Testing.ReconnectInfo> __Marshaller_ReconnectInfo = Marshallers.Create((arg) => global::Google.Protobuf.MessageExtensions.ToByteArray(arg), global::Grpc.Testing.ReconnectInfo.Parser.ParseFrom);

    static readonly Method<global::Grpc.Testing.ReconnectParams, global::Grpc.Testing.Empty> __Method_Start = new Method<global::Grpc.Testing.ReconnectParams, global::Grpc.Testing.Empty>(
        MethodType.Unary,
        __ServiceName,
        "Start",
        __Marshaller_ReconnectParams,
        __Marshaller_Empty);

    static readonly Method<global::Grpc.Testing.Empty, global::Grpc.Testing.ReconnectInfo> __Method_Stop = new Method<global::Grpc.Testing.Empty, global::Grpc.Testing.ReconnectInfo>(
        MethodType.Unary,
        __ServiceName,
        "Stop",
        __Marshaller_Empty,
        __Marshaller_ReconnectInfo);

    /// <summary>Service descriptor</summary>
    public static global::Google.Protobuf.Reflection.ServiceDescriptor Descriptor
    {
      get { return global::Grpc.Testing.TestReflection.Descriptor.Services[2]; }
    }

    /// <summary>Base class for server-side implementations of ReconnectService</summary>
    public abstract class ReconnectServiceBase
    {
      public virtual global::System.Threading.Tasks.Task<global::Grpc.Testing.Empty> Start(global::Grpc.Testing.ReconnectParams request, ServerCallContext context)
      {
        throw new RpcException(new Status(StatusCode.Unimplemented, ""));
      }

      public virtual global::System.Threading.Tasks.Task<global::Grpc.Testing.ReconnectInfo> Stop(global::Grpc.Testing.Empty request, ServerCallContext context)
      {
        throw new RpcException(new Status(StatusCode.Unimplemented, ""));
      }

    }

    /// <summary>Client for ReconnectService</summary>
    public class ReconnectServiceClient : ClientBase<ReconnectServiceClient>
    {
      /// <summary>Creates a new client for ReconnectService</summary>
      /// <param name="channel">The channel to use to make remote calls.</param>
      public ReconnectServiceClient(Channel channel) : base(channel)
      {
      }
      /// <summary>Creates a new client for ReconnectService that uses a custom <c>CallInvoker</c>.</summary>
      /// <param name="callInvoker">The callInvoker to use to make remote calls.</param>
      public ReconnectServiceClient(CallInvoker callInvoker) : base(callInvoker)
      {
      }
      /// <summary>Protected parameterless constructor to allow creation of test doubles.</summary>
      protected ReconnectServiceClient() : base()
      {
      }
      /// <summary>Protected constructor to allow creation of configured clients.</summary>
      /// <param name="configuration">The client configuration.</param>
      protected ReconnectServiceClient(ClientBaseConfiguration configuration) : base(configuration)
      {
      }

      public virtual global::Grpc.Testing.Empty Start(global::Grpc.Testing.ReconnectParams request, Metadata headers = null, DateTime? deadline = null, CancellationToken cancellationToken = default(CancellationToken))
      {
        return Start(request, new CallOptions(headers, deadline, cancellationToken));
      }
      public virtual global::Grpc.Testing.Empty Start(global::Grpc.Testing.ReconnectParams request, CallOptions options)
      {
        return CallInvoker.BlockingUnaryCall(__Method_Start, null, options, request);
      }
      public virtual AsyncUnaryCall<global::Grpc.Testing.Empty> StartAsync(global::Grpc.Testing.ReconnectParams request, Metadata headers = null, DateTime? deadline = null, CancellationToken cancellationToken = default(CancellationToken))
      {
        return StartAsync(request, new CallOptions(headers, deadline, cancellationToken));
      }
      public virtual AsyncUnaryCall<global::Grpc.Testing.Empty> StartAsync(global::Grpc.Testing.ReconnectParams request, CallOptions options)
      {
        return CallInvoker.AsyncUnaryCall(__Method_Start, null, options, request);
      }
      public virtual global::Grpc.Testing.ReconnectInfo Stop(global::Grpc.Testing.Empty request, Metadata headers = null, DateTime? deadline = null, CancellationToken cancellationToken = default(CancellationToken))
      {
        return Stop(request, new CallOptions(headers, deadline, cancellationToken));
      }
      public virtual global::Grpc.Testing.ReconnectInfo Stop(global::Grpc.Testing.Empty request, CallOptions options)
      {
        return CallInvoker.BlockingUnaryCall(__Method_Stop, null, options, request);
      }
      public virtual AsyncUnaryCall<global::Grpc.Testing.ReconnectInfo> StopAsync(global::Grpc.Testing.Empty request, Metadata headers = null, DateTime? deadline = null, CancellationToken cancellationToken = default(CancellationToken))
      {
        return StopAsync(request, new CallOptions(headers, deadline, cancellationToken));
      }
      public virtual AsyncUnaryCall<global::Grpc.Testing.ReconnectInfo> StopAsync(global::Grpc.Testing.Empty request, CallOptions options)
      {
        return CallInvoker.AsyncUnaryCall(__Method_Stop, null, options, request);
      }
      /// <summary>Creates a new instance of client from given <c>ClientBaseConfiguration</c>.</summary>
      protected override ReconnectServiceClient NewInstance(ClientBaseConfiguration configuration)
      {
        return new ReconnectServiceClient(configuration);
      }
    }

    /// <summary>Creates service definition that can be registered with a server</summary>
    public static ServerServiceDefinition BindService(ReconnectServiceBase serviceImpl)
    {
      return ServerServiceDefinition.CreateBuilder()
          .AddMethod(__Method_Start, serviceImpl.Start)
          .AddMethod(__Method_Stop, serviceImpl.Stop).Build();
    }

  }
}
#endregion
