using System.Threading.Channels;

namespace eBiblioteka.Api.Services.Recommender;

// Javlja pozadinskom poslu da treba preračunati sličnost knjiga (npr. nakon nove ili izmijenjene ocjene).
public interface IRecalculationTrigger
{
    void Request();
}

public sealed class RecalculationTrigger : IRecalculationTrigger
{
    // Kanal veličine 1: više zahtjeva u nizu se spaja u jedan.
    private readonly Channel<bool> _channel = Channel.CreateBounded<bool>(
        new BoundedChannelOptions(1) { FullMode = BoundedChannelFullMode.DropWrite });

    public ChannelReader<bool> Reader => _channel.Reader;

    public void Request() => _channel.Writer.TryWrite(true);
}
