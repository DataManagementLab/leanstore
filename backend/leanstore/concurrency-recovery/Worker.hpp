#pragma once
#include "Transaction.hpp"
#include "WALEntry.hpp"
// -------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------
#include <atomic>
#include <functional>
#include <mutex>
#include <vector>
// -------------------------------------------------------------------------------------
namespace leanstore
{
namespace cr
{
// -------------------------------------------------------------------------------------
struct Worker {
   // Static
   static atomic<u64> central_tts;
   static thread_local Worker* tls_ptr;
   // -------------------------------------------------------------------------------------
   Worker(u64 worker_id, Worker** all_workers, u64 workers_count);
   ~Worker();
   // -------------------------------------------------------------------------------------
   // Shared with all workers
   atomic<u64> high_water_mark = 0;  // High water mark: TS > mark are visible
   atomic<u64> active_tts = 0;
   // -------------------------------------------------------------------------------------
   unique_ptr<u64[]> my_snapshot;
   unique_ptr<u64[]> my_concurrent_transcations;
   // -------------------------------------------------------------------------------------
   // Protect W+GCT shared data (worker <-> group commit thread)
   std::mutex worker_group_commiter_mutex;
   // -------------------------------------------------------------------------------------
   std::vector<Transaction> ready_to_commit_queue;
   // -------------------------------------------------------------------------------------
   // Accessible only by the group commit thread
   struct GroupCommitData {
      u64 ready_to_commit_cut = 0;  // Exclusive ) == size
      u64 max_safe_gsn_to_commit = std::numeric_limits<u64>::max();
      LID gsn_to_flush;
      u64 wt_cursor_to_flush;
      u64 bytes_to_ignore_in_the_next_round = 0;
   };
   GroupCommitData group_commit_data;
   // -------------------------------------------------------------------------------------
   LID clock_gsn;
   // -------------------------------------------------------------------------------------
   // START WAL
   // -------------------------------------------------------------------------------------
   static constexpr s64 WORKER_WAL_SIZE = 1024 * 1024 * 10;
   static constexpr s64 CR_ENTRY_SIZE = sizeof(WALMetaEntry);
   // -------------------------------------------------------------------------------------
   // Published using mutex
   atomic<u64> wal_wt_cursor = 0;  // W->GCT
   atomic<LID> wal_max_gsn = 0;    // W->GCT, under mutex
   // -------------------------------------------------------------------------------------
   atomic<u64> wal_ww_cursor = 0;                // GCT->W
   alignas(512) u8 wal_buffer[WORKER_WAL_SIZE];  // W->GCT
   LID wal_lsn_counter = 0;
   // -------------------------------------------------------------------------------------
   u32 walFreeSpace();
   u32 walContiguousFreeSpace();
   void walEnsureEnoughSpace(u32 requested_size);
   u8* walReserve(u32 requested_size);
   // -------------------------------------------------------------------------------------
   // Iterate over current TX entries
   u64 current_tx_wal_start;
   void iterateOverCurrentTXEntries(std::function<void(const WALEntry& entry)> callback);
   // -------------------------------------------------------------------------------------
   // END WAL
   // -------------------------------------------------------------------------------------
   static inline Worker& my() { return *Worker::tls_ptr; }
   u64 worker_id;
   Worker** all_workers;
   const u64 workers_count;
   // -------------------------------------------------------------------------------------
   Transaction tx;
   WALDTEntry* active_dt_entry;
   // -------------------------------------------------------------------------------------
   inline LID getCurrentGSN() { return clock_gsn; }
   inline void setCurrentGSN(LID gsn) { clock_gsn = gsn; }
   // -------------------------------------------------------------------------------------
  private:
   // Without Payload, by submit no need to update clock (gsn)
   WALMetaEntry& reserveWALMetaEntry();
   void submitWALMetaEntry();

  public:
   // -------------------------------------------------------------------------------------
   void startTX();
   void commitTX();
   void abortTX();
   // -------------------------------------------------------------------------------------
   bool isVisibleForMe(u64 tts);
   // -------------------------------------------------------------------------------------
   template <typename T>
   class WALEntryHandler
   {
     public:
      u8* entry;
      u64 total_size;
      inline T* operator->() { return reinterpret_cast<T*>(entry); }
      inline T& operator*() { return *reinterpret_cast<T*>(entry); }
      WALEntryHandler() = default;
      WALEntryHandler(u8* entry, u64 size) : entry(entry), total_size(size) {}
      void submit() { cr::Worker::my().submitDTEntry(total_size); }
   };
   // -------------------------------------------------------------------------------------
   template <typename T>
   WALEntryHandler<T> reserveDTEntry(u64 requested_size, PID pid, LID gsn, DTID dt_id)
   {
      const u64 total_size = sizeof(WALDTEntry) + requested_size;
      ensure(walContiguousFreeSpace() >= total_size);
      active_dt_entry = reinterpret_cast<WALDTEntry*>(wal_buffer + wal_wt_cursor);
      active_dt_entry->type = WALEntry::TYPE::DT_SPECIFIC;
      active_dt_entry->size = total_size;
      active_dt_entry->lsn = wal_lsn_counter++;
      // -------------------------------------------------------------------------------------
      active_dt_entry->pid = pid;
      active_dt_entry->gsn = gsn;
      active_dt_entry->dt_id = dt_id;
      return {active_dt_entry->payload, total_size};
   }
   void submitDTEntry(u64 requested_size);
};
// -------------------------------------------------------------------------------------
}  // namespace cr
}  // namespace leanstore
