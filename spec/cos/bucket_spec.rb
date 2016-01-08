require 'spec_helper'

module COS

  describe Bucket do

    before :all do
      stub_request(:get, "http://web.file.myqcloud.com/files/v1/100000/bucket_name/?op=stat").
          to_return(:status => 200, :body => { code: 0, message: 'ok', data: {}}.to_json)

      @config = {
          app_id: '100000',
          secret_id: 'secret_id',
          secret_key: 'secret_key',
          protocol: 'http',
          default_bucket: 'bucket_name'
      }
      @bucket = Client.new(@config).bucket('bucket_name')
    end

    it 'should list folder' do
      stub_request(:get, 'http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/?context=&num=20&op=list&order=0&pattern=eListDirOnly').
          to_return(:status => 200, :body => {
              code: 0,
              message: 'ok',
              data: {
                  has_more: false,
                  context: '',
                  infos: [
                      {name: 'f1', ctime: Time.now.to_i.to_s, mtime: Time.now.to_i.to_s, biz_attr: ''},
                      {name: 'f2', ctime: Time.now.to_i.to_s, mtime: Time.now.to_i.to_s, biz_attr: ''}
                         ]
              }
          }.to_json, :headers => {})

      size = 0
      @bucket.list('/path/', {pattern: :dir_only}).each do |f|
        size += 1
      end

      expect(WebMock).to have_requested(:get, 'http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/?context=&num=20&op=list&order=0&pattern=eListDirOnly')

      expect(size).to eq(2)
    end

    it 'should resource operators' do

      @time = Time.now.to_i.to_s

      stub_request(:get, 'http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/?context=&num=20&op=list&order=0&pattern=eListBoth').
          to_return(:status => 200, :body => {
              code: 0,
              message: 'ok',
              data: {
                  has_more: false,
                  context: '',
                  infos: [
                                {name: 'd1', ctime: @time, mtime: @time, biz_attr: ''},
                                {name: 'd2', ctime: @time, mtime: @time, biz_attr: ''},
                                {name: 'f1', ctime: @time, mtime: @time, biz_attr: '', filesize: 100, filelen:100},
                            ]
              }
          }.to_json, :headers => {})

      stub_request(:post, "http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/d1/").to_return(:status => 200, :body => { code: 0, message: 'ok', data: {ctime: @time, mtime: @time}}.to_json)

      stub_request(:post, "http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/d1/path2/").to_return(:status => 200, :body => { code: 0, message: 'ok', data: {ctime: @time, mtime: @time}}.to_json)

      stub_request(:post, "http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/d2/").to_return(:status => 200, :body => { code: 0, message: 'ok', data: {ctime: @time, mtime: @time}}.to_json)

      stub_request(:post, "http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/d2/path2/").to_return(:status => 200, :body => { code: 0, message: 'ok', data: {ctime: @time, mtime: @time}}.to_json)

      stub_request(:post, "http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/f1").to_return(:status => 200, :body => { code: 0, message: 'ok', data: {ctime: @time, mtime: @time}}.to_json)

      stub_request(:get, "http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/d1/?op=stat").to_return(:status => 200, :body => { code: 0, message: 'ok', data: {name: 'd1', ctime: @time, mtime: @time, biz_attr: ''}}.to_json)

      stub_request(:get, "http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/d2/?op=stat").to_return(:status => 200, :body => { code: 0, message: 'ok', data: {name: 'd2', ctime: @time, mtime: @time, biz_attr: ''}}.to_json)

      stub_request(:get, "http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/f1?op=stat").to_return(:status => 200, :body => { code: 0, message: 'ok', data: {name: 'f1', filesize: 100, ctime: @time, mtime: @time, biz_attr: ''}}.to_json)

      stub_request(:get, "http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/f1?op=stat").to_return(:status => 400, :body => { code: -166, message: '索引不存在'}.to_json)

      @bucket.list('/path/').each do |f|

        if f.is_a?(COS::COSDir) and f.type == 'dir'
          expect(f.created_at).to eq(Time.at(@time.to_i))
          expect(f.updated_at).to eq(Time.at(@time.to_i))
          expect(f.stat.name).to eq(f.name)

          expect(f.update('111biz_attr').biz_attr).to eq('111biz_attr')

          f.create_folder('path2')

        elsif f.is_a?(COS::COSFile) and f.type == 'file'
          expect(f.to_hash[:filesize]).to eq(100)
          expect(f.complete?).to eq(true)
          f.delete
          expect(f.exist?).to eq(false)
        else
          nil
        end

      end

      expect(WebMock).to have_requested(:get, 'http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/?context=&num=20&op=list&order=0&pattern=eListBoth')

      expect(WebMock).to have_requested(:post, 'http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/f1')
      expect(WebMock).to have_requested(:post, 'http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/d1/')
      expect(WebMock).to have_requested(:post, 'http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/d2/')

    end

    it 'should get stat , raise when exception, exist?' do

      @time = Time.now.to_i.to_s

      stub_request(:get, 'http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/?context=&num=20&op=list&order=0&pattern=eListBoth').
          to_return(:status => 200, :body => {
              code: 0,
              message: 'ok',
              data: {
                  has_more: false,
                  context: '',
                  infos: [
                                {name: 'd1', ctime: @time, mtime: @time, biz_attr: ''},
                                {name: 'f1', ctime: @time, mtime: @time, biz_attr: '', filesize: 100, filelen:100},
                            ]
              }
          }.to_json, :headers => {})

      stub_request(:get, 'http://web.file.myqcloud.com/files/v1/100000/bucket_name/?context=&num=1&op=list&order=0&pattern=eListBoth').
          to_return(:status => 200, :body => {
              code: 0,
              message: 'ok',
              data: {
                  has_more: false,
                  dircount: 1,
                  filecount: 1,
                  context: '',
                  infos: [
                                {name: 'd1', ctime: @time, mtime: @time, biz_attr: ''},
                            ]
              }
          }.to_json, :headers => {})

      stub_request(:get, "http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/f1?op=stat").to_return(:status => 200, :body => { code: 0, message: 'ok', data: {name: 'f1', filesize: 100, filelen:100, ctime: @time, mtime: @time, biz_attr: ''}}.to_json).times(2)

      stub_request(:get, "http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/d1/?op=stat").to_return(:status => 400, :body => { code: -111, message: '未知错误'}.to_json)

      expect(@bucket.count).to eq(2)

      @bucket.list('/path/', {}).each do |f|
        if f.is_a?(COS::COSFile) and f.type == 'file'
          expect(f.exist?).to eq(true)
          expect(f.stat.file_size).to eq(100)
        else
          expect do
            f.exist?
          end.to raise_error(ServerError)
        end
      end
    end

    it 'upload file slice to a path' do
      @time = Time.now.to_i.to_s

      stub_request(:get, 'http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/?context=&num=20&op=list&order=0&pattern=eListFileOnly').
          to_return(:status => 200, :body => {
              code: 0,
              message: 'ok',
              data: {
                  has_more: false,
                  context: '',
                  infos: [
                                {name: 'd1', ctime: @time, mtime: @time, biz_attr: ''},
                                {name: 'f1', ctime: @time, mtime: @time, biz_attr: '', filesize: 100, filelen:100},
                            ]
              }
          }.to_json, :headers => {})

      stub_request(:post, 'http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/d1/test_file').
          to_return(:status => 200, :body => {
              code: 0, message: 'ok', data: {session: 'session', slice_size: 10000, offset: 0, access_url: 'access_url'}
          }.to_json)

      stub_request(:get, "http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/d1/test_file?op=stat").to_return(:status => 200, :body => {
          code: 0, message: 'ok', data: {name: 'f1', filesize: 100, filelen:100, ctime: @time, mtime: @time, biz_attr: ''}
      }.to_json)

      @file = './file_to_upload.log'
      @file_name = 'test_file'

      File.delete("#{@file}.cpt") if File.exist?("#{@file}.cpt")
      File.delete("#{@file}") if File.exist?("#{@file}")

      File.open(@file, 'w') do |f|
        (1..100).each do |i|
          f.puts i.to_s.rjust(100, '0')
        end
      end

      @bucket.list('/path/', {pattern: :file_only}).each do |f|
        if f.is_a?(COS::COSDir) and f.type == 'dir'
          slice = 0
          f.upload(@file_name, @file, min_slice_size: 1) do
            slice += 1
          end

          expect(slice).to eq(0)
        end
      end

      File.delete("#{@file}.cpt") if File.exist?("#{@file}.cpt")
      File.delete("#{@file}") if File.exist?("#{@file}")
    end

    it 'upload file entire to a path, and errors' do
      @time = Time.now.to_i.to_s

      stub_request(:get, 'http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/?context=&num=20&op=list&order=0&pattern=eListBoth').
          to_return(:status => 200, :body => {
              code: 0,
              message: 'ok',
              data: {
                  has_more: false,
                  context: '',
                  infos: [
                                {name: 'd1', ctime: @time, mtime: @time, biz_attr: ''},
                                {name: 'f1', ctime: @time, mtime: @time, biz_attr: '', filesize: 100, filelen:100},
                            ]
              }
          }.to_json, :headers => {})

      stub_request(:post, 'http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/d1/test_file')
          .to_return(:status => 400, :body => {
              code: -999, message: 'server error' }.to_json).then
          .to_return(:status => 200, :body => {
              code: 0, message: 'ok', data: {session: 'session', slice_size: 10000, offset: 0, access_url: 'access_url'}
          }.to_json)

      stub_request(:get, "http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/d1/test_file?op=stat").to_return(:status => 200, :body => {
          code: 0, message: 'ok', data: {name: 'f1', filesize: 100, filelen:100, ctime: @time, mtime: @time, biz_attr: ''}
      }.to_json)

      @file = './file_to_upload.log'
      @file_name = 'test_file'

      File.delete("#{@file}.cpt") if File.exist?("#{@file}.cpt")
      File.delete("#{@file}") if File.exist?("#{@file}")

      File.open(@file, 'w') do |f|
        (1..100).each do |i|
          f.puts i.to_s.rjust(100, '0')
        end
      end

      @bucket.list('/path/', {}).each do |f|
        if f.is_a?(COS::COSDir) and f.type == 'dir'
          slice = 0
          f.upload(@file_name, @file, min_slice_size: 1000000) do
            slice += 1
          end

          expect(slice).to eq(0)
        end
      end

      File.delete("#{@file}.cpt") if File.exist?("#{@file}.cpt")
      File.delete("#{@file}") if File.exist?("#{@file}")
    end

    it 'upload file entire to a path, raise error' do
      @time = Time.now.to_i.to_s

      stub_request(:get, 'http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/?context=&num=20&op=list&order=0&pattern=eListBoth').
          to_return(:status => 200, :body => {
              code: 0,
              message: 'ok',
              data: {
                  has_more: false,
                  context: '',
                  infos: [
                                {name: 'd1', ctime: @time, mtime: @time, biz_attr: ''},
                                {name: 'f1', ctime: @time, mtime: @time, biz_attr: '', filesize: 100, filelen:100},
                            ]
              }
          }.to_json, :headers => {})

      stub_request(:post, 'http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/d1/test_file')
          .to_return(:status => 400, :body => {
              code: -999, message: 'server error' }.to_json).times(4)

      @file = './file_to_upload.log'
      @file_name = 'test_file'

      File.delete("#{@file}.cpt") if File.exist?("#{@file}.cpt")
      File.delete("#{@file}") if File.exist?("#{@file}")

      File.open(@file, 'w') do |f|
        (1..100).each do |i|
          f.puts i.to_s.rjust(100, '0')
        end
      end

      @bucket.list('/path/', {}).each do |f|
        if f.is_a?(COS::COSDir) and f.type == 'dir'
          expect do
            f.upload(@file_name, @file, min_slice_size: 1000000, upload_retry: 3)
          end.to raise_error(ServerError)
        end
      end

      expect(WebMock).to have_requested(:post, 'http://web.file.myqcloud.com/files/v1/100000/bucket_name/path/d1/test_file').times(4)

      File.delete("#{@file}.cpt") if File.exist?("#{@file}.cpt")
      File.delete("#{@file}") if File.exist?("#{@file}")
    end

  end

end