Pod::Spec.new do |s|
  s.name         = 'ZLPhotoBrowser'
  s.version      = '1.0.1'
  s.summary      = 'An easy way to Multiselect photos from ablum'
  s.homepage     = 'https://github.com/longitachi/ZLPhotoBrowser'
  s.license      = 'MIT'
  s.platform     = :ios
  s.author       = {'longitachi' => 'longitachi@163.com'}
  s.ios.deployment_target = '8.0'
  s.source       = {:git => 'https://github.com/longitachi/ZLPhotoBrowser.git', :tag => s.version}
  s.source_files = 'ZLPhotoBrowser/PhotoBrowser/*.{h,m}'
  s.resources    = 'ZLPhotoBrowser/PhotoBrowser/resource/*.{png,xib,nib}'
  s.requires_arc = true
  s.frameworks   = 'UIKit','Photos'
end
