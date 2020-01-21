class RlsLookupCacheTest : ::google::testing {
  
};

class FakeCacheEntry : RlsLookupCache::CacheEntry {
public:
  FakeCacheEntry(bool should_remove) : should_remove_(should_remove) {}
  ~FakeCacheEntry() {}

  virtual bool ShouldRemove() override { return should_remove_; }
private:
  bool should_remove_;
};

TEST_F(RlsLookupCacheTest, AddAndDeleteEntry) {
  auto cache = RlsLookupCache();
  CacheKey key = make_pair(grpc::string("/grpc.testing.EchoTestService/Echo"), {{grpc_string("myKey"), grpc_string("keyX")}});
  CacheKey key2 = make_pair(grpc::string("/grpc.testing.EchoTestService/Echo"), {{grpc_string("myKey"), grpc_string("keyY")}});
  cache.Add(key, RefCountedPtr<CacheEntry>(new FakeCacheEntry(false)));
  EXPECT_EQ(cache.Count(), 1);
  cache.Delete(key2);
  EXPECT_EQ(cache.Count(), 1);
  cache.Delete(key);
  EXPECT_EQ(cache.Count(), 0);
}

TEST_F(RlsLookupCacheTest, FindEntry) {
  auto cache = RlsLookupCache();
  CacheKey key1 = make_pair(grpc::string("/grpc.testing.EchoTestService/Echo"), {{grpc_string("myKey"), grpc_string("keyX")}});
  CacheKey key2 = make_pair(grpc::string("/grpc.testing.EchoTestService/Echo"), {{grpc_string("myKey"), grpc_string("keyY")}});
  CacheKey key3 = make_pair(grpc::string("/grpc.testing.EchoTestService/Null"), {{grpc_string("myKey"), grpc_string("keyX")}});
  CacheKey key4 = make_pair(grpc::string("/grpc.testing.EchoTestService/Echo"), {{grpc_string("myKey"), grpc_string("keyZ")}});
  cache.Add(key1, RefCountedPtr<CacheEntry>(new FakeCacheEntry(false)));
  cache.Add(key4, RefCountedPtr<CacheEntry>(new FakeCacheEntry(true)));
  EXPECT_EQ(cache.Count(), 2);
  auto result1 = cache.Find(key1);
  auto result2 = cache.Find(key2);
  auto result3 = cache.Find(key3);
  auto result4 = cache.Find(key4);
  EXPECT_EQ(cache.Count(), 1);
  EXPECT_NE(result1, nullptr);
  EXPECT_EQ(result2, nullptr);
  EXPECT_EQ(result3, nullptr);
  EXPECT_EQ(result4, nullptr);
}

TEST_F(RlsLookupCacheTest, TimerRemoveEntry) {
  int64_t timer_period_seconds = 1;
  auto cache = RlsLookupCache(timer_period_seconds);
  CacheKey key1 = make_pair(grpc::string("/grpc.testing.EchoTestService/Echo"), {{grpc_string("myKey"), grpc_string("keyX")}});
  cache.Add(key1, RefCountedPtr<CacheEntry>(new FakeCacheEntry(true)));
  EXPECT_EQ(cache.Count(), 1);
  sleep(timer_period_seconds + 1);
  EXPECT_EQ(cache.Count(), 0);
}

TEST_F(RlsLookupCacheTest, LruEviction) {
  int64_t cache_size = 2;
  auto cache = RlsLookupCache(100, 2);
  CacheKey key1 = make_pair(grpc::string("/grpc.testing.EchoTestService/Echo"), {{grpc_string("myKey"), grpc_string("keyX")}});
  CacheKey key2 = make_pair(grpc::string("/grpc.testing.EchoTestService/Echo"), {{grpc_string("myKey"), grpc_string("keyY")}});
  CacheKey key3 = make_pair(grpc::string("/grpc.testing.EchoTestService/Echo"), {{grpc_string("myKey"), grpc_string("keyZ")}});
  auto entry1 = RefCountedPtr<CacheEntry>(new FakeCacheEntry(false));
  auto entry2 = RefCountedPtr<CacheEntry>(new FakeCacheEntry(false));
  auto entry3 = RefCountedPtr<CacheEntry>(new FakeCacheEntry(false));
  cache.Add(key1, entry1);
  cache.Add(key2, entry2);
  cache.Add(key3, entry3);
  EXPECT_EQ(cache.Count(), 2);
  EXPECT_EQ(cache.Find(key1), nullptr);
  EXPECT_NE(cache.Find(key2), nullptr);
  EXPECT_NE(cache.Find(key3), nullptr);
  
  // Refresh key2 entry so that it's more recently used than key3
  cache.Refresh(key2);
  cache.Add(key1, entry1);
  EXPECT_EQ(cache.Count(), 2);
  EXPECT_NE(cache.Find(key1), nullptr);
  EXPECT_NE(cache.Find(key2), nullptr);
  EXPECT_EQ(cache.Find(key3), nullptr);
}

TEST_F(RlsLookupCacheEntryTest, TestShouldRemove) {
  // Pending RLS request
  RlsLookupCacheEntry entry1;
  entry1.state = RlsLookupCacheEntry::PENDING;

  EXPECT_EQ(entry1.ShouldRemove() == false);

  // SUCCEEDED and current
  RlsLookupCacheEntry entry2;
  entry2.state = RlsLookupCacheEntry::SUCCEEDED;
  entry2.expiration_time = //current time + 5s;
  entry2.stale_time = //current time + 1s;

  EXPECT_EQ(entry2.ShouldRemove() == false);

  // SUCCEEDED and stale
  RlsLookupCacheEntry entry3;
  entry3.state = RlsLookupCacheEntry::SUCCEEDED;
  entry3.expiration_time = //current time + 5s;
  entry3.stale_time = //current time - 1s;

  EXPECT_EQ(entry3.ShouldRemove() == false);

  // SUCCEEDED and expired, but with pending call
  RlsLookupCacheEntry entry4;
  entry4.state = RlsLookupCacheEntry::SUCCEEDED;
  entry4.expiration_time = //current time - 1s;
  entry4.stale_time = //current time - 2s;
  entry4.pending_call = RefCountedPtr<CallState>(static_cast<CallState*>(1));

  EXPECT_EQ(entry4.ShouldRemove() == false);
  // Check state is updated.
  EXPECT_EQ(entry4.state == RlsLookupCacheEntry::PENDING);

  // SUCCEEDED and expired
  RlsLookupCacheEntry entry5;
  entry5.state = RlsLookupCacheEntry::SUCCEEDED;
  entry5.expiration_time = //current time - 1s;
  entry5.stale_time = //current time - 2s;

  EXPECT_EQ(entry5.ShouldRemove() == true);
}

class RlsLookupCacheEntry : RlsLookupCache::CacheEntry {
public:
  enum class State { PENDING, SUCCEEDED };
  State state;
  grpc_millis expiration_time;
  grpc_millis stale_time;
  RefCountedPtr<CallState> pending_call;

  RefCountedPtr<ChildPolicyWrapper> child_policy_wrapper;
  grpc_string header_data;

  bool HasValidChildPolicy();
  bool ShouldRemove() override;
};

class RlsLookupCache {
public:
  using CacheKey = std::pair<grpc::string, std::map<grpc::string, grpc::string>>;

  class CacheEntry {
  public:
    // Check whether an entry should be removed from the cache. The state of the entry may also be updated as necessary.
    virtual bool ShouldRemove() = 0;
  };
  RlsLookupCache(int64_t timer_period_seconds, int64_t cache_size);
  ~RlsLookupCache();

  /** Find a cached entry corresponding to a key. */
  RefCountedPtr<CacheEntry> Find(const CacheKey& key);

  /** Add a cached entry to the end of the LRU list. If an entry of the same key exists, the original entry is kept and the cache will not be affected. */
  void Add(const CacheKey& key, RefCountedPtr<CacheEntry> entry, RefCountedPtr<CacheEntry>* evicted_entry);

  /** Move a cached entry to the end of the LRU list. */
  void Refresh(const CacheKey& key);

  /** Delete a cached entry. */
  void Delete(const CacheKey& key);

  /** Return the number of entries in the cache. */
  int64_t Count() const;
};
