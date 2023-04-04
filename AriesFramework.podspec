
Pod::Spec.new do |spec|

  spec.name         = "AriesFramework"
  spec.version      = "1.2.1"
  spec.summary      = "Aries Framework Swift"
  spec.license      = "Apache License"

  spec.homepage     = "https://github.com/hyperledger/aries-framework-swift"
  spec.author       = { "conanoc" => "conanoc@gmail.com" }

  spec.source       = { :git => "" }
  spec.source_files = "AriesFramework/AriesFramework/**/*.{h,swift}"

  spec.dependency   "Indy", "1.16.2"
  spec.dependency   "Base58Swift", "~> 2.1"
  spec.dependency   "WebSockets", "~> 0.5.0"
  spec.dependency   "CollectionConcurrencyKit", "~> 0.2.0"
  spec.static_framework        = true

  spec.platform     = :ios
  spec.ios.deployment_target   = "15.0"

end
