using System;
using System.Threading.Tasks;
using BarRaider.SdTools;
using Fleck;
using Newtonsoft.Json;
using StreamDeckVSC.Messages;

namespace StreamDeckVSC
{
    public class Client
    {
        private readonly IWebSocketConnection socket;

        public IWebSocketConnection Connection => socket;

        public Client(IWebSocketConnection socket) => this.socket = socket;

        public void Send(object data)
        {
            try
            {
                var payload = Serialize(new Message { Id = data.GetType().Name, Data = Serialize(data) });

                // Fleck's Send returns a Task; observe it so a send failure is logged
                // rather than surfacing as an unobserved task exception.
                socket.Send(payload).ContinueWith(
                    task => Logger.Instance.LogMessage(TracingLevel.ERROR, $"Failed to send message: {task.Exception}"),
                    TaskContinuationOptions.OnlyOnFaulted);
            }
            catch (Exception ex)
            {
                Logger.Instance.LogMessage(TracingLevel.ERROR, $"Error sending message: {ex}");
            }
        }

        private string Serialize(object data) => JsonConvert.SerializeObject(data);
    }
}
