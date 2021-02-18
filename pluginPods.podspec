# https://blog.csdn.net/xiangzhihong8/article/details/85135865
Pod::Spec.new do |s|
    s.name         = 'TCLocationManager'
    s.version      = '0.0.1'
    s.summary      = '定位插件'
    s.homepage     = 'https://github.com/tianchuan/TCLocationManager'
    s.license      = 'MIT'
    s.authors      = {'tianchuan' => 'tian_chuan614@sina.com'}
    s.platform     = :ios, '8.0'
    s.source       = {:git => 'https://github.com/tianchuan/TCLocationManager.git', :tag => s.version}
    s.source_files = 'TCLocationManager/*'
end
