require 'net/https'
require 'uri'
require 'json'
require 'date'

uri = URI.parse('https://qiita.com/')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request_header = { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{ENV['QIITA_TOKEN']}" }

round = 0

# ページングしながらQiitaの全記事を取得
(1..100).each do |i|
  get_url = "https://qiita.com/api/v2/users/#{ENV['USER_ID']}/items?page=#{i}&per_page=100"

  get_request = Net::HTTP::Get.new(get_url, request_header)

  get_response = http.request(get_request)

  items = JSON.parse(get_response.response.body)

  break if items.empty?

  items.each do |item|
    round += 1

    if round >= 357
      break
    end

    puts "#{round} #{item['url']}"
    puts "#{item['title']} (#{item['body'].length}文字)"

    title = item['title'].slice(0..69)

    # item['created_At'] の値の例
    # 2023-08-25T21:01:00+09:00

    # 複数回実行しても記事が重複しないようにQiitaの記事作成日時をslugとして利用する
    slug = item['created_at'].gsub(':', '_').gsub('+', '-').gsub('T', 't') + '_'

    original_created_at_date = item['created_at'].gsub(/T.+/, '')

    filepath = "../../zennn/articles/qiita-#{slug}.md"

    future_publish_at ||= Time.now
    future_publish_at += 60 * 60

    puts filepath

    # Qiitaのタグをそのままzennで使う
    tag_names = item['tags'].map { |tag| tag['name'] }

    # Qiitaでポエムタグがついている記事はideaに、そうでない記事はtechに分類する
    type = if tag_names.include?('ポエム') || tag_names.include?('Qiita')
             'idea'
           else
             'tech'
           end

    filebody = <<~EOM
      ---
      title: #{title.to_json}
      emoji: "🖥"
      type: "#{type}"
      topics: #{tag_names}
      published: true
      published_at: #{future_publish_at.strftime('%Y-%m-%d %H:%M')}
      ---

      #{item['body'].slice(0..75_000)}

      # 公開日時

      #{original_created_at_date}
    EOM

    # puts filebody

    file = File.open(filepath, 'w')
    file.write(filebody)
    file.close
  end

  sleep 1
end
