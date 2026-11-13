defmodule WatchClub.MediaSources.Import.Ingestor.ExtractStructure.TextTracks do
  @moduledoc """
  Internal helper for `ExtractStructure`. Decides the language and region of a video's Text
  Tracks, and which ones are forced or SDH.

  Files often mark them wrong, so it also reads each track's title, which for a sidecar file
  is the end of its name: "French (Canada)", "VFQ", "English SDH", "en.hi", "Forced", "Full".
  A track marked forced is a full one when its title says so, or when its language matches
  none of the audio tracks'.
  """

  alias WatchClub.Languages
  alias WatchClub.MediaSources.Import.Candidate.MediaStructure

  @forced_words ~w(forced foreign force forces signs)
  @full_words ~w(full complet complete completo)
  # `hi` is also Hindi's code
  @sdh_words ~w(sdh shd cc hi sme malentendants hearing deaf)

  # The region or script each word names. `european` leaves it to the language.
  @regions %{
    "canada" => "CA",
    "canadian" => "CA",
    "canadien" => "CA",
    "canadienne" => "CA",
    "quebec" => "CA",
    "quebecois" => "CA",
    "quebecoise" => "CA",
    "vfq" => "CA",
    "france" => "FR",
    "parisian" => "FR",
    "parisien" => "FR",
    "vff" => "FR",
    "spain" => "ES",
    "espana" => "ES",
    "espagne" => "ES",
    "castilian" => "ES",
    "castellano" => "ES",
    "castillan" => "ES",
    "latin" => "419",
    "latine" => "419",
    "latino" => "419",
    "latinoamerica" => "419",
    "latinoamericano" => "419",
    "latam" => "419",
    "brazil" => "BR",
    "brazilian" => "BR",
    "brasil" => "BR",
    "brasileiro" => "BR",
    "bresil" => "BR",
    "bresilien" => "BR",
    "portugal" => "PT",
    "simplified" => "Hans",
    "simplifie" => "Hans",
    "traditional" => "Hant",
    "traditionnel" => "Hant"
  }
  @european_words ~w(european europeen europeenne europe)
  @european_regions %{"es" => "ES", "pt" => "PT", "fr" => "FR"}

  # Some files give their tracks a release's name as title, such as
  # `Signs.2002.1080p.BluRay.x264-GROUP`, whose words say nothing about the track. It has one of
  # these words, and many others, unlike a title such as "English - Forced - 1080p".
  @release_word ~r/^(\d{3,4}p|[xh]26[45]|hevc|bluray|webrip|webdl|hdtv|dvdrip|brrip)$/
  @release_name_min_words 5

  @doc "Decides the `language`, `forced?` and `sdh?` of the structure's Text Tracks."
  @spec classify(MediaStructure.t()) :: MediaStructure.t()
  def classify(%MediaStructure{} = structure) do
    audio_languages = Enum.map(structure.audio_tracks, &Languages.to_code(&1.language))

    %{structure | text_tracks: Enum.map(structure.text_tracks, &classify(&1, audio_languages))}
  end

  defp classify(track, audio_languages) do
    # Tokens keep the hyphens of tags such as `pt-BR`, words split them
    tokens = (track.title || "") |> normalize() |> String.split(~r/[^\p{L}\p{N}-]+/u, trim: true)
    words = Enum.flat_map(tokens, &String.split(&1, "-", trim: true))

    {tokens, words} =
      if length(words) >= @release_name_min_words and Enum.any?(words, &(&1 =~ @release_word)),
        do: {[], []},
        else: {tokens, words}

    language = language(track.language, tokens, words)
    code = Languages.to_code(language)
    sdh_words = if code == "hi", do: @sdh_words -- ["hi"], else: @sdh_words

    %{
      track
      | language: language,
        sdh?: track.sdh? or Enum.any?(words, &(&1 in sdh_words)),
        forced?:
          cond do
            Enum.any?(words, &(&1 in @full_words)) -> false
            Enum.any?(words, &(&1 in @forced_words)) -> true
            # An audio track without a language may be in any
            track.forced? -> code in audio_languages or nil in audio_languages
            true -> false
          end
    }
  end

  # The language of the file's marker, else the one the title names. With the region the marker
  # names, else the title, by a code such as `fr-CA` or by a word such as "Canada".
  defp language(marker, tokens, words) do
    title_code = code_in(tokens)
    tag = Languages.to_tag(marker) || Enum.find_value(words, &language_name/1) || title_code
    code = Languages.to_code(tag)

    region =
      Enum.find_value(words, fn word ->
        if word in @european_words, do: @european_regions[code], else: @regions[word]
      end)

    cond do
      tag != code -> tag
      Languages.to_code(title_code) == code and title_code != code -> title_code
      region -> Languages.to_tag("#{code}-#{region}")
      true -> tag
    end
  end

  # A code such as `en` or `pt-br`, nearest the end first. A title's other words are often codes
  # too, such as `sdh` or `srt`, so only languages with a two-letter code count, and `hi` names
  # Hindi only without another language.
  defp code_in(tokens) do
    tokens
    |> Enum.reject(&(&1 in (@sdh_words -- ["hi"]) or &1 in @forced_words or &1 in @full_words))
    |> Enum.reverse()
    |> Enum.sort_by(&(&1 == "hi"))
    |> Enum.find_value(fn token ->
      tag = Languages.to_tag(token)
      if String.length(Languages.to_code(tag) || "") == 2, do: tag
    end)
  end

  # Single-word language names in English and French, such as "french" or "francais"
  @language_names for locale <- [:en, :fr],
                      {code, %{standard: name}} <-
                        WatchClub.Cldr.Language.known_languages(locale),
                      is_binary(code) and String.length(code) == 2,
                      name =
                        name
                        |> String.downcase()
                        |> :unicode.characters_to_nfd_binary()
                        |> String.replace(~r/\p{Mn}/u, ""),
                      not String.contains?(name, " "),
                      not Map.has_key?(@regions, name),
                      into: %{},
                      do: {name, code}

  defp language_name(word), do: @language_names[word]

  # Lowercase, without accents
  defp normalize(text) do
    text
    |> String.downcase()
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/\p{Mn}/u, "")
  end
end
