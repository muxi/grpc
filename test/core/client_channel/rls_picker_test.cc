class RlsPickerTest : ::google::testing {
  
};

TEST(RlsKeyBuilderMapTest, ParseConfig) {
  // grpc_json config_json;
  // Normal parsing
  grpc_error *error;
  KeyBuilder builder = ParseKeyBuilderConfig(config_json, &error);
  EXPECT_EQ(error, nullptr);
  EXPECT_EQ(builder.map().size(), 2);
  
  // Configs with conflicting service/method names.
  //grpc_json config_json;
  KeyBuilder builder = ParseKeyBuilderConfig(config_json, &error);
  EXPECT_NE(error, nullptr);
}

TEST(RlsKeyBuilderMapTest, Vanilla) {
  KeyBuilder builder({{"key1", {"fieldX", "fieldY"}},{"key2", {"fieldY","fieldZ"}},{"key3", {"fieldX"}}});
  auto key = builder.BuildKey({"fieldY", "valY"}, {"fieldZ", "valZ"});
  EXPECT_EQ(key["key1"], "valY");
  EXPECT_EQ(key["key2"], "valY");
  EXPECT_EQ(key.find("key3"), key.end);
}

TEST(RlsKeyBuilderMapTest, SameFieldMultipleTimes) {
  KeyBuilder builder({{"key1", {"fieldX", "fieldY"}});
  auto key = builder.BuildKey({"fieldX", "valX1"}, {"fieldX", "valX2"}, {"fieldY", "valY1"}, {"fieldY", "valY2"});
  EXPECT_EQ(key["key1"], "valX1,valX2");
}

class KeyBuilder final {
  using Key = std::map<grpc::string, grpc::string>;

  KeyBuilder(std::map<grpc::string, std::vector<grpc::string>>);

  Key BuildKey(grpc_metadata_batch *headers);
};


