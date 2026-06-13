using System;
using System.Collections.Concurrent;
using System.Linq;
using BarRaider.SdTools;
using Fleck;
using Newtonsoft.Json;
using StreamDeckVSC.Messages;

namespace StreamDeckVSC
{
    public class MessageServer : IDisposable
    {
        private readonly WebSocketServer server;

        // Fleck invokes connection callbacks on thread-pool threads, so the
        // connection map must be thread-safe. A plain Dictionary here could throw
        // (e.g. KeyNotFoundException / corruption) under concurrent access, which
        // escaped the Fleck OnMessage callback and caused Fleck to close the
        // socket with code 1011 on every ChangeActiveSessionMessage.
        private static readonly ConcurrentDictionary<Guid, Client> connections = new ConcurrentDictionary<Guid, Client>();

        public static Client CurrentClient { get; private set; }

        public MessageServer(string host, int port)
        {
            // Surface Fleck's internal logging (including the "Application error"
            // it logs right before closing a socket with 1011) through the same
            // NLog pipeline SdTools uses, so failures are visible in pluginlog.log.
            FleckLog.LogAction = (level, message, ex) =>
            {
                // Skip Fleck's per-frame Debug chatter ("Sent N bytes" / "N bytes read");
                // forward Info and above, which is where connection failures surface.
                if (level == LogLevel.Debug)
                {
                    return;
                }

                var tracing = level switch
                {
                    LogLevel.Error => TracingLevel.ERROR,
                    LogLevel.Warn => TracingLevel.WARN,
                    _ => TracingLevel.INFO,
                };

                Logger.Instance.LogMessage(tracing, ex is null ? $"[Fleck] {message}" : $"[Fleck] {message} :: {ex}");
            };

            server = new WebSocketServer($"ws://{host}:{port}");
        }

        public void Start()
        {
            Logger.Instance.LogMessage(TracingLevel.INFO, $"Starting server {server.Location}");

            server.Start(connection =>
            {
                connection.OnOpen = () => OnConnected(connection);
                connection.OnClose = () => OnDisconnected(connection);
                connection.OnMessage = message => OnMessage(connection, message);
            });
        }

        private void OnDisconnected(IWebSocketConnection connection)
        {
            var id = connection.ConnectionInfo.Id;

            connections.TryRemove(id, out _);

            Logger.Instance.LogMessage(TracingLevel.INFO, $"Client disconnected {id}. {connections.Count} client(s) remaining.");

            TryActivateRemainingClient();
        }

        private void OnConnected(IWebSocketConnection connection)
        {
            var id = connection.ConnectionInfo.Id;

            connections[id] = new Client(connection);

            Logger.Instance.LogMessage(TracingLevel.INFO, $"Client connected {id}. {connections.Count} client(s) total.");

            TryActivateRemainingClient();
        }

        private void TryActivateRemainingClient()
        {
            if (connections.Count == 1)
            {
                var client = connections.First().Value;

                if (client.Connection.ConnectionInfo.Headers.TryGetValue("X-VSSessionID", out var sessionId))
                {
                    SetActiveSession(client.Connection.ConnectionInfo.Id, sessionId);
                }
            }
        }

        private void OnMessage(IWebSocketConnection connection, string rawMessage)
        {
            // Never let an exception escape this callback: Fleck treats any throw
            // from OnMessage as an application error and closes the socket (1011).
            try
            {
                Logger.Instance.LogMessage(TracingLevel.INFO, $"{rawMessage}");

                var message = JsonConvert.DeserializeObject<Message>(rawMessage);

                if (!string.IsNullOrEmpty(message?.Data))
                {
                    if (message.Id == nameof(ChangeActiveSessionMessage))
                    {
                        var changeActiveSession = JsonConvert.DeserializeObject<ChangeActiveSessionMessage>(message.Data);

                        SetActiveSession(connection.ConnectionInfo.Id, changeActiveSession.SessionId);
                    }
                }
            }
            catch (Exception ex)
            {
                Logger.Instance.LogMessage(TracingLevel.ERROR, $"Error handling message '{rawMessage}': {ex}");
            }
        }

        private void SetActiveSession(Guid clientId, string sessionId)
        {
            if (!connections.TryGetValue(clientId, out var current))
            {
                return;
            }

            CurrentClient = current;

            var activeSessionChanged = new ActiveSessionChangedMessage(sessionId);

            foreach (var client in connections.Values)
            {
                client.Send(activeSessionChanged);
            }
        }

        public void Dispose() => server?.Dispose();
    }
}
