# coding: utf-8

require 'time'
require 'base64'
require 'openssl'
require 'uri'

module COS

  class Signature

    attr_reader :config, :expire_seconds, :file_id

    # 初始化
    #
    # @example
    #   COS::Signature.new(config)
    #
    # @param config [COS::Config] 客户端设置
    #
    # @see COS::Config
    def initialize(config)
      @config = config
    end

    # 生成签名headers
    #
    # @see https://cloud.tencent.com/document/product/436/7778#signature
    #
    # @note COS基于密钥 HMAC 的自定义 HTTP 方案进行身份验证
    #
    # @param method [String] HTTP 请求方法
    # @param uri [String] HTTP 请求 URI 部分 即从“/”虚拟根路径开始部分
    # @param parameters [Hash] HTTP 请求参数
    # @param headers [Hash] HTTP 请求header
    #
    # @return [Hash] 加入Authorization的签名headers
    def authorization(method, uri = '/', parameters = {}, headers = {})
      current_date = Time.now
      start = current_date.to_i
      expire = start + 60 * 30
      # 临时密钥的有效起止时间
      q_key_time = start.to_s + ';' + expire.to_s

      sign_key = OpenSSL::HMAC.hexdigest('sha1', config.secret_key, q_key_time)
      format_param = URI.encode_www_form(parameters)
      format_header = URI.encode_www_form(headers)

      # 签名
      # [HttpMethod]\n[HttpURI]\n[HttpParameters]\n[HttpHeaders]\n
      http_string = method + "\n" + uri + "\n" + format_param + "\n" + format_header + "\n"
      sha1_string = Digest::SHA1.hexdigest http_string
      # [q-sign-algorithm]\n[q-sign-time]\nsha1($HttpString)\n
      string_to_signature = 'sha1' + "\n" + q_key_time + "\n" + sha1_string + "\n"

      signature_key = OpenSSL::HMAC.hexdigest('sha1', sign_key, string_to_signature)

      authorization_dict = {
          'q-sign-algorithm': 'sha1',
          'q-ak': config.secret_id,
          'q-sign-time': q_key_time,
          'q-key-time': q_key_time,
          'q-header-list': headers.keys.join(';'),
          'q-url-param-list': '',
          'q-signature': signature_key
      }
      key_arr = []
      authorization_dict.each {|key, value|
        key_arr.push key.to_s + '=' + value
      }
      key_string = key_arr.join '&'

      headers['date'] = current_date.strftime('%a, %d %b %Y %H:%M:%S GMT')
      headers['authorization'] = key_string
      headers
    end

    # 单次有效签名
    #
    # @see http://www.qcloud.com/wiki/%E9%89%B4%E6%9D%83%E6%8A%80%E6%9C%AF%E6%9C%8D%E5%8A%A1%E6%96%B9%E6%A1%88#1_.E7.AD.BE.E5.90.8D.E4.B8.8E.E9.89.B4.E6.9D.83
    #
    # @note 用于删除目录、文件, 更新目录、文件
    #
    # @param bucket [String] bucket名称
    # @param path [String] 文件或目录路径, 如 /path/, /path/file
    #
    # @return [String] 签名字符串
    def once(bucket, path)
      # 单次签名,需要指定资源存储的唯一标识
      unless path.start_with?('/')
        path = "/#{path}"
      end

      # 资源存储的唯一标识，格式为"/app_id/bucket/用户自定义路径或资源名"
      @file_id = "/#{config.app_id}/#{bucket}#{path}"

      sign(:once, bucket)
    end


    # 多次有效签名
    #
    # @see http://www.qcloud.com/wiki/%E9%89%B4%E6%9D%83%E6%8A%80%E6%9C%AF%E6%9C%8D%E5%8A%A1%E6%96%B9%E6%A1%88#1_.E7.AD.BE.E5.90.8D.E4.B8.8E.E9.89.B4.E6.9D.83
    #
    # @note 用于上传,查询目录、文件,查询目录、文件,创建目录,下载（开启token防盗链）
    #
    # @param bucket [String] bucket名称
    # @param expire_seconds [Integer] 签名有效时间(单位秒)
    #
    # @return [String] 签名字符串
    def multiple(bucket, expire_seconds = config.multiple_sign_expire)
      # 多次签名时，过期时间应大于当前时间
      if expire_seconds <= 0
        raise AttrError, 'Multiple signature expire_seconds must greater than 0'
      end

      @expire_seconds = expire_seconds

      sign(:multiple, bucket)
    end

    private

    # 生成签名
    #
    # @see http://www.qcloud.com/wiki/%E9%89%B4%E6%9D%83%E6%8A%80%E6%9C%AF%E6%9C%8D%E5%8A%A1%E6%96%B9%E6%A1%88#2.3.09.E7.94.9F.E6.88.90.E7.AD.BE.E5.90.8D
    def sign(sign_type, bucket)
      # 准备待签名字符串
      sign_string = string_to_sign(sign_type, bucket)

      # HMAC-SHA1算法进行签名
      hmac_sha1 = OpenSSL::HMAC.digest('sha1', config.secret_key, sign_string)

      # 然后将原字符串附加到签名结果的末尾，再进行Base64编码
      Base64.strict_encode64("#{hmac_sha1}#{sign_string}")
    end

    # 准备签名字符串
    #
    # @see http://www.qcloud.com/wiki/%E9%89%B4%E6%9D%83%E6%8A%80%E6%9C%AF%E6%9C%8D%E5%8A%A1%E6%96%B9%E6%A1%88#2_.E7.AD.BE.E5.90.8D.E7.AE.97.E6.B3.95
    def string_to_sign(sign_type, bucket)
      # 随机串，无符号10进制整数，最长10位
      r = rand(99999)

      # 当前时间戳，是一个符合UNIX Epoch时间戳规范的数值，单位为秒
      t = Time.now.to_i

      if sign_type == :once
        # 单次签名时e为0
        e = 0

        # 需要对其中非'/'字符进行urlencode编码
        f = URI.encode(file_id)

      elsif sign_type == :multiple
        e = t + expire_seconds

        # 多次签名不需要提供file_id
        f = nil

      else
        raise Exception, 'Unknown sign type when prepare sign string'
      end

      # 拼接待签名字符串
      "a=#{config.app_id}&b=#{bucket}&k=#{config.secret_id}&e=#{e}&t=#{t}&r=#{r}&f=#{f}"
    end

  end

end