
class FileProcessingJob < ApplicationJob
  queue_as :default

  def perform(file_id)
    @processed_file = ProcessedFile.find(file_id)
    filename = @processed_file.text_file.filename
    file_content = @processed_file.text_file.download
    complete_text = ensure_utf8(file_content)
    snippet = extract_snippet(complete_text)

    p "Processing file: #{filename}, snippet: #{snippet}, type: #{@processed_file.text_type}"
    @processed_file.name = filename
    @processed_file.snippet = snippet
    @processed_file.save

    audio_file = call_tts(complete_text, @processed_file.text_type, @processed_file.name)
    p audio_file

    @processed_file.audio_file.attach(io: File.open(Rails.root.join(audio_file)), filename: File.basename(audio_file))
    FileUtils.rm_f(audio_file)

    #sleep 5
    #p "broadcasting ..."
    #Turbo::StreamsChannel.broadcast_stream_to(@processed_file,
    #          content: ApplicationController.render(:turbo_stream,
    #            partial: "processed_files/processed_file",
    #  locals: {processed_file: @processed_file}))

    #ActionCable.server.broadcast "processed_files:#{}"

    #ProcessedFilesController.render(partial: 'processed_files/processed_file', locals: { processed_file: @processed_file})
    #@processed_file.broadcast_replace_to(:create, @processed_file)

    #p "============ UPDATED FILE ===================="
    #broadcasts_to -> (processed_file) { "processed_files" }, inserts_by: :prepend

  end

  def call_tts(text, format, filename)
    TtsService.call(text, format, filename)
  end
  private

  def ensure_utf8(text)
    text.bytes.pack("c*").force_encoding("UTF-8")
  end

  def extract_snippet(text)
    if text.length > 50
      snippet = text[0, 50]
    else
      snippet = text
    end
    snippet
  end
end
