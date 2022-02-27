defmodule ChanaUtils do
  use Supervisor

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [ChanaUtilsConsumer]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule ChanaUtilsConsumer do
  use Nostrum.Consumer

  alias Nostrum.Api
  alias Nostrum.Cache.GuildCache
  alias Nostrum.Voice

  require Logger

  @play_command %{
    name: "play",
    description: "play a song from the url",
    options: [
      %{
        # ApplicationCommandType::ROLE = 8
        type: 3,
        name: "url",
        description: "The link to the song",
        required: true
      }
    ]
  }

@pause_command %{
    name: "pause",
    description: "pause a song that's currently playing"
}

  # %{
  #   # ApplicationCommandType::STRING
  #   type: 3,
  #   name: "action",
  #   description: "whether to assign or remove the role",
  #   required: true,
  #   choices: [
  #     %{
  #       name: "assign",
  #       value: "assign"
  #     },
  #     %{
  #       name: "remove",
  #       value: "remove"
  #     }
  #   ]
  # }

  @spec start_link :: :ignore | {:error, any} | {:ok, pid}
  def start_link do
    Consumer.start_link(__MODULE__)
  end

  @spec get_voice_channel_of_msg(atom | %{:guild_id => non_neg_integer, optional(any) => any}) ::
          any
  def get_voice_channel_of_msg(msg) do
    msg.guild_id
    |> GuildCache.get!()
    |> Map.get(:voice_states)
    |> Enum.find(%{}, fn v -> v.user_id == msg.author.id end)
    |> Map.get(:channel_id)
  end

  @spec get_voice_channel_of_interaction(
          atom
          | %{:guild_id => non_neg_integer, optional(any) => any}
        ) :: any
  def get_voice_channel_of_interaction(interaction) do
    interaction.guild_id
    |> GuildCache.get!()
    |> Map.get(:voice_states)
    |> Enum.find(%{}, fn v -> v.user_id == interaction.member.user.id end)
    |> Map.get(:channel_id)
  end

  @spec do_not_ready_msg(
          atom
          | %{:channel_id => non_neg_integer | Nostrum.Struct.Message.t(), optional(any) => any}
        ) ::
          {:error,
           %{
             response:
               binary | %{:code => 1..1_114_111, :message => binary, optional(:errors) => map},
             status_code: 1..1_114_111
           }}
          | {:ok, Nostrum.Struct.Message.t()}
  def do_not_ready_msg(msg) do
    Api.create_message(msg.channel_id, "I need to be in a voice channel for that.")
  end

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    case msg.content do
      "p!summon" ->
        case get_voice_channel_of_msg(msg) do
          nil ->
            Api.create_message(msg.channel_id, "Must be in a voice channel to summon")

          voice_channel_id ->
            Voice.join_channel(msg.guild_id, voice_channel_id)
        end

      "p!leave" ->
        Voice.leave_channel(msg.guild_id)

      "p!pause" ->
        Voice.pause(msg.guild_id)

      "p!resume" ->
        Voice.resume(msg.guild_id)

      "p!stop" ->
        Voice.stop(msg.guild_id)

      _ ->
        :noop
    end
  end

  def handle_event({:VOICE_SPEAKING_UPDATE, payload, _ws_state}) do
    Logger.debug("VOICE SPEAKING UPDATE #{inspect(payload)}")
  end

  def handle_event({:READY, _data, _ws_state}) do
    Nostrum.Api.create_guild_application_command("850377546046636093", @play_command)
    Nostrum.Api.create_guild_application_command("910444948724269086", @play_command)
    Nostrum.Api.create_guild_application_command("935001754989367396", @play_command)
    Nostrum.Api.create_guild_application_command("925645184639860837", @play_command)

    Nostrum.Api.create_guild_application_command("850377546046636093", @pause_command)
    Nostrum.Api.create_guild_application_command("910444948724269086", @pause_command)
    Nostrum.Api.create_guild_application_command("935001754989367396", @pause_command)
    Nostrum.Api.create_guild_application_command("925645184639860837", @pause_command)
    Logger.info("Command Registered")

    Api.update_status(:online, "you :D", 3)
  end

  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    Logger.debug("INTERACTION CREATE #{inspect(interaction.data.name)}")

    if(interaction.data.name == "play") do
      url =
        for option <- interaction.data.options do
          urll =
            case option.name do
              "url" ->
                option.value
            end

          urll
        end

      if not Voice.ready?(interaction.guild_id) do
        case get_voice_channel_of_interaction(interaction) do
          nil ->
            response = %{
              type: 4,
              data: %{
                # ephemeral
                flags: 64,
                content: "Must be in a voice channel to play"
              }
            }

            Nostrum.Api.create_interaction_response(interaction, response)

            voice_channel_id ->
            Voice.join_channel(interaction.guild_id, voice_channel_id)

            response = %{
              type: 4,
              data: %{
                content: "Playing #{url}"
              }
            }

            Logger.debug("Sending response #{inspect(url)}")
            Nostrum.Api.create_interaction_response(interaction, response)

            Task.start(fn ->
              Process.sleep(1000)
              Voice.play(interaction.guild_id, url, :ytdl, realtime: false)
            end)
        end
      else
        response = %{
          type: 4,
          data: %{
            content: "Playing #{url}"
          }
        }

        Logger.debug("Sending response #{inspect(url)}")
        Nostrum.Api.create_interaction_response(interaction, response)

        Task.start(fn ->
          Voice.play(interaction.guild_id, url, :ytdl, realtime: false)
        end)
      end
      if(interaction.data.name == "pause") do
        Voice.pause(interaction.guild_id)

        response = %{
          type: 4,
          data: %{
            content: "Paused"
          }
        }

        Logger.debug("Sending response #{inspect(url)}")
        Nostrum.Api.create_interaction_response(interaction, response)
      end
    end

  end

  def handle_event({:VOICE_SPEAKING_UPDATE, voice_data, _ws_state}) do
    if(voice_data.speaking) do
      
    end
  end

  def handle_event(_event) do
    :noop
  end
end
