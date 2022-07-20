
class FileProcessingJob < ApplicationJob
  queue_as :default

  def perform(file_id)
    @processed_file = ProcessedFile.find(file_id)
    filename = @processed_file.text_file.filename
    file_content = @processed_file.text_file.download
    complete_text = ensure_utf8(file_content)
    snippet = extract_snippet(complete_text)
    ActionCable.server.broadcast "notifications", {html:
                                                                "<div class='alert alert-warning alert-block text-center'>
        <i class='fa fa-circle-o-notch fa-spin'></i>
        talgervill er að framleiða hljóðskrá fyrir #{filename}.
    </div>"
    }

    p "Processing file: #{filename}, snippet: #{snippet}, type: #{@processed_file.text_type}"
    @processed_file.name = filename
    @processed_file.snippet = snippet
    @processed_file.save

    audio_file = call_tts(complete_text, @processed_file.text_type, @processed_file.name)
    p audio_file

    @processed_file.audio_file.attach(io: File.open(Rails.root.join(audio_file)), filename: File.basename(audio_file))
    FileUtils.rm_f(audio_file)
    ActionCable.server.broadcast "notifications", {html:
                                                                "<div class='alert alert-success alert-block text-center'>
        Hljóðskrá tilbúin!
     </div>"
      }

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
