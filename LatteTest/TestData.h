
#define kTestJSONMarkup @"{\"@layout\":[{\"@isa\":\"UILabel\",\"@id\":\"l1\",\"backgroundColor\":\"@color-hex:00abb0\",\"text\":\"#{@bind(object.foo)}\",\"textColor\":\"@color:white\",\"translatesAutoresizingMaskIntoConstraints\":false,\"textAlignment\":1,\"cornerRadius\":8,\"@subviews\":[{\"@isa\":\"UIImageView\",\"@id\":\"image1\",\"frame\":[0,0,10,10]}]},{\"@isa\":\"UILabel\",\"@id\":\"l2\",\"backgroundColor\":\"@color-hex:00CCF0\",\"text\":\"Hello #{object.foo} and #{@bind(object.bar)}\",\"textColor\":\"@color:white\",\"translatesAutoresizingMaskIntoConstraints\":false,\"textAlignment\":1,\"cornerRadius\":8}],\"@constraints\":[{\"format\":\"H:|-margin-[l1(140)]-margin-[l2(80)]\",\"options\":[\"baseline\"],\"metrics\":{\"margin\":30}},{\"format\":\"V:|-[l1(50)]\"},{\"format\":\"V:|-[l2(50)]\"}]}"