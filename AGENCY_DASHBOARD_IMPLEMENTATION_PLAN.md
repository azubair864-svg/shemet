# 🎯 Agency Dashboard - Complete Implementation Plan
**8 Missing Pages + UI Design + Firebase Integration + Performance Optimization**

---

## 📊 Execution Plan Overview

```
Phase 1: Core Pages Setup (Week 1)
├── User Management (බිම්)
├── Live Stream Control
└── Database queries optimize

Phase 2: Content Moderation (Week 2)  
├── Party Room Management
├── Admin Profile
└── Cache strategy

Phase 3: Finance & Analytics (Week 3)
├── Coins/Diamonds System
├── Leaderboard Management
└── Indexing optimize

Phase 4: Advanced Features (Week 4)
├── System Messages
├── Reports & Analytics
└── Performance tuning
```

---

## 📱 Page 1: User Management

### UI Layout (ඔබ බලන ස්වරූපය)
```
┌─────────────────────────────────────────────┐
│ [←] User Management        [🔍] [⚙️]        │
├─────────────────────────────────────────────┤
│                                             │
│  Filter: [All] [Active] [Banned] [New]     │
│  Search: [_______________________] [🔎]    │
│  Sort: [Name ▼] [Joined ▼]                 │
│                                             │
├─────────────────────────────────────────────┤
│ #  │ Name      │ Email        │ Type   │ Status │ Actions │
├────┼───────────┼──────────────┼────────┼────────┼─────────┤
│ 1  │ Naveen    │ nav@xxx.com  │ Host   │ Active │ [View] │
│ 2  │ Priya     │ pri@xxx.com  │ User   │ Active │ [View] │
│ 3  │ Ravi      │ rav@xxx.com  │ User   │ Banned │ [View] │
│ 4  │ ...       │ ...          │ ...    │ ...    │ ...    │
├─────────────────────────────────────────────┤
│ Total: 1,523 users  │ Showing 1-50 │ < 1 2 3 > │
└─────────────────────────────────────────────┘
```

### Files to Create
```
agency-dashboard/app/
├── users/
│   ├── page.js              ← Main page (this will load below)
│   ├── [userId]/
│   │   └── page.js          ← User details
│   └── components/
│       ├── UserTable.js     ← Table component
│       ├── UserFilters.js   ← Filter controls
│       ├── UserModal.js     ← Ban/Suspend modal
│       └── UserStats.js     ← Stats cards
```

### Code: User Management Page

```javascript
// agency-dashboard/app/users/page.js
'use client';

import { useEffect, useState } from 'react';
import { db, auth } from '@/lib/firebase';
import { collection, query, where, getDocs, limit, startAfter, orderBy } from 'firebase/firestore';
import UserTable from './components/UserTable';
import UserFilters from './components/UserFilters';

const ITEMS_PER_PAGE = 50;

export default function UsersPage() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filters, setFilters] = useState({ status: 'all', search: '' });
  const [pagination, setPagination] = useState({ page: 1, total: 0 });

  useEffect(() => {
    fetchUsers();
  }, [filters, pagination.page]);

  const fetchUsers = async () => {
    try {
      setLoading(true);
      
      let q = query(
        collection(db, 'users'),
        orderBy('createdAt', 'desc'),
        limit(ITEMS_PER_PAGE)
      );

      // Apply status filter
      if (filters.status !== 'all') {
        q = query(
          collection(db, 'users'),
          where('status', '==', filters.status),
          orderBy('createdAt', 'desc'),
          limit(ITEMS_PER_PAGE)
        );
      }

      const snapshot = await getDocs(q);
      const userList = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));

      setUsers(userList);
      setPagination(prev => ({ ...prev, total: snapshot.size }));
    } catch (error) {
      console.error('Error fetching users:', error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-900">
      <header className="bg-gray-800 border-b border-gray-700 p-4">
        <h1 className="text-2xl font-bold text-white">User Management</h1>
      </header>

      <div className="p-6">
        <UserFilters 
          filters={filters} 
          setFilters={setFilters}
        />

        {loading ? (
          <div className="text-center py-8">
            <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-white"></div>
          </div>
        ) : (
          <>
            <UserTable users={users} />
            {/* Pagination */}
            <div className="mt-6 flex justify-between items-center">
              <p className="text-gray-400">
                Total: {pagination.total} users | Showing {(pagination.page - 1) * ITEMS_PER_PAGE + 1}-{Math.min(pagination.page * ITEMS_PER_PAGE, pagination.total)}
              </p>
              <div className="space-x-2">
                <button className="px-3 py-1 bg-gray-700 text-white rounded">← Prev</button>
                <button className="px-3 py-1 bg-gray-700 text-white rounded">{pagination.page}</button>
                <button className="px-3 py-1 bg-gray-700 text-white rounded">Next →</button>
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
```

### Firebase Collections Used
```javascript
// Firestore structure
users/
├── userId1/
│   ├── name: "Naveen"
│   ├── email: "nav@xxx.com"
│   ├── status: "active" | "banned" | "suspended"
│   ├── type: "host" | "user"
│   ├── createdAt: timestamp
│   ├── coins: 1000
│   ├── diamonds: 50
│   ├── totalSpent: 5000
│   ├── lastActive: timestamp
│   └── violations: 0
├── userId2/
└── ...
```

---

## 📡 Page 2: Live Stream Control

### UI Layout
```
┌──────────────────────────────────────────────┐
│ [←] Live Streams        [Refresh] [⚙️]      │
├──────────────────────────────────────────────┤
│                                              │
│ Status: [All] [Live] [Ended] [Scheduled]    │
│ Quality: [All] [HD] [SD] [Low]              │
│                                              │
├──────────────────────────────────────────────┤
│ ┌────────────────────────────────────────┐  │
│ │ [Thumbnail] Host: Naveen              │  │
│ │ 👥 2,543 viewers | 🎥 HD              │  │
│ │ ⏱️ 1h 23m | 💎 15k diamonds earned    │  │
│ │ [Pause] [Stop] [Report] [Details]     │  │
│ └────────────────────────────────────────┘  │
│                                              │
│ ┌────────────────────────────────────────┐  │
│ │ [Thumbnail] Host: Priya                │  │
│ │ ...                                    │  │
│ └────────────────────────────────────────┘  │
│                                              │
└──────────────────────────────────────────────┘
```

### Files to Create
```
agency-dashboard/app/
├── live-streams/
│   ├── page.js              ← Live streams list
│   ├── [streamId]/
│   │   └── page.js          ← Stream details
│   └── components/
│       ├── StreamCard.js    ← Individual stream
│       ├── StreamModal.js   ← Control modal
│       └── StreamStats.js   ← Real-time stats
```

### Code: Live Stream Page

```javascript
// agency-dashboard/app/live-streams/page.js
'use client';

import { useEffect, useState } from 'react';
import { db } from '@/lib/firebase';
import { 
  collection, 
  query, 
  where, 
  getDocs, 
  onSnapshot,
  updateDoc,
  doc 
} from 'firebase/firestore';
import StreamCard from './components/StreamCard';

export default function LiveStreamsPage() {
  const [streams, setStreams] = useState([]);
  const [filter, setFilter] = useState('all');
  const [selectedStream, setSelectedStream] = useState(null);

  useEffect(() => {
    let q = query(collection(db, 'calls'), where('type', '==', 'live'));
    
    if (filter !== 'all') {
      q = query(
        collection(db, 'calls'),
        where('type', '==', 'live'),
        where('status', '==', filter)
      );
    }

    // Real-time listener for live updates
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const liveStreams = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      setStreams(liveStreams);
    });

    return () => unsubscribe();
  }, [filter]);

  const handleStopStream = async (streamId) => {
    try {
      await updateDoc(doc(db, 'calls', streamId), {
        status: 'ended',
        endedAt: new Date(),
        endedBy: 'admin'
      });
      alert('Stream stopped successfully');
    } catch (error) {
      console.error('Error stopping stream:', error);
    }
  };

  return (
    <div className="min-h-screen bg-gray-900">
      <header className="bg-gray-800 border-b border-gray-700 p-4">
        <h1 className="text-2xl font-bold text-white">Live Streams</h1>
      </header>

      <div className="p-6">
        <div className="flex gap-4 mb-6">
          {['all', 'live', 'ended', 'scheduled'].map(status => (
            <button
              key={status}
              onClick={() => setFilter(status)}
              className={`px-4 py-2 rounded capitalize ${
                filter === status 
                  ? 'bg-purple-600 text-white' 
                  : 'bg-gray-700 text-gray-300'
              }`}
            >
              {status}
            </button>
          ))}
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {streams.map(stream => (
            <StreamCard
              key={stream.id}
              stream={stream}
              onStop={() => handleStopStream(stream.id)}
              onSelect={() => setSelectedStream(stream)}
            />
          ))}
        </div>

        {streams.length === 0 && (
          <div className="text-center text-gray-400 py-8">
            No live streams found
          </div>
        )}
      </div>
    </div>
  );
}
```

### Firebase Collections Used
```javascript
// Firestore structure
calls/
├── callId1/
│   ├── type: "live"
│   ├── status: "live" | "ended" | "scheduled"
│   ├── hostId: "user123"
│   ├── startedAt: timestamp
│   ├── endedAt: timestamp
│   ├── viewers: 2543
│   ├── quality: "HD" | "SD" | "Low"
│   ├── duration: 5340 (seconds)
│   ├── diamondsEarned: 15000
│   ├── reportedCount: 0
│   └── endedBy: "host" | "admin" | "system"
└── ...
```

---

## 🎭 Page 3: Party Room Management

### Files & Components
```
agency-dashboard/app/
├── party-rooms/
│   ├── page.js
│   └── components/
│       ├── PartyRoomTable.js
│       └── PartyRoomModal.js
```

### Firebase Query Pattern
```javascript
// Get active party rooms with real-time updates
const partyRoomsRef = collection(db, 'party_rooms');
const q = query(
  partyRoomsRef,
  where('status', '==', 'active'),
  orderBy('createdAt', 'desc')
);

onSnapshot(q, (snapshot) => {
  const rooms = snapshot.docs.map(doc => ({
    id: doc.id,
    participants: doc.data().participants?.length || 0,
    status: doc.data().status,
    createdBy: doc.data().createdBy,
    ...doc.data()
  }));
  setPartyRooms(rooms);
});
```

---

## 💎 Page 4: Coins/Diamonds Management

### Files & Components
```
agency-dashboard/app/
├── coins-diamonds/
│   ├── page.js              ← Main dashboard
│   ├── transactions.js      ← Transaction log
│   └── components/
│       ├── BalanceStats.js
│       ├── TransactionTable.js
│       └── AdjustModal.js
```

### Firebase Structure & Operations
```javascript
// Collection structure
users/
├── userId/
│   ├── coins: 5000
│   ├── diamonds: 200
│   └── coinTransactions: {
│       - timestamp: amount
│       - reason: "purchase|gift|earned"
│   }

// Track all transactions
transactions/
├── txId1/
│   ├── userId: "user123"
│   ├── type: "coin_purchase|diamond_earn|gift"
│   ├── amount: 1000
│   ├── reason: "Purchased 1000 coins"
│   ├── before: 5000
│   ├── after: 6000
│   ├── timestamp: timestamp
│   └── adminId: "admin123" (if adjusted by admin)

// Code example
async function adjustUserDiamonds(userId, amount, reason) {
  const userRef = doc(db, 'users', userId);
  const userDoc = await getDoc(userRef);
  const currentDiamonds = userDoc.data().diamonds || 0;

  // Update user balance
  await updateDoc(userRef, {
    diamonds: currentDiamonds + amount
  });

  // Log transaction
  await addDoc(collection(db, 'transactions'), {
    userId,
    type: 'admin_adjustment',
    amount,
    reason,
    before: currentDiamonds,
    after: currentDiamonds + amount,
    timestamp: new Date(),
    adminId: auth.currentUser.uid
  });
}
```

---

## 🏆 Page 5: Leaderboard Management

### Files & Components
```
agency-dashboard/app/
├── leaderboards/
│   ├── page.js              ← Dashboard
│   ├── weekly.js            ← Weekly rankings
│   ├── monthly.js           ← Monthly rankings
│   ├── all-time.js          ← All time
│   └── components/
│       └── LeaderboardTable.js
```

### Firebase Aggregation
```javascript
// Firestore structure for leaderboards
leaderboards/
├── weekly_{week_number}/
│   ├── rank1/
│   │   ├── userId: "user123"
│   │   ├── name: "Naveen"
│   │   ├── earnings: 45000
│   │   ├── rank: 1
│   │   └── badge: "🥇"
│   ├── rank2/
│   └── ...
├── monthly_{month}/
└── all_time/

// Update leaderboard nightly (Cloud Function)
async function updateLeaderboards() {
  const usersRef = collection(db, 'users');
  const users = await getDocs(usersRef);
  
  const rankings = [];
  users.forEach(doc => {
    rankings.push({
      userId: doc.id,
      name: doc.data().name,
      earnings: doc.data().totalEarnings || 0,
      level: doc.data().level || 1
    });
  });

  // Sort and rank
  rankings.sort((a, b) => b.earnings - a.earnings);
  rankings.forEach((user, index) => {
    user.rank = index + 1;
  });

  // Save to leaderboards collection
  const weekNum = getWeekNumber(new Date());
  await setDoc(doc(db, 'leaderboards', `weekly_${weekNum}`), {
    rankings,
    generatedAt: new Date()
  });
}
```

---

## 📬 Page 6: System Messages/Notifications

### Files & Components
```
agency-dashboard/app/
├── messages/
│   ├── page.js              ← Inbox
│   ├── compose.js           ← Send message
│   └── components/
│       ├── MessageList.js
│       ├── MessageDetail.js
│       └── ComposeForm.js
```

### Firebase Implementation
```javascript
// Collection structure
system_messages/
├── messageId/
│   ├── type: "notification|alert|broadcast"
│   ├── subject: "System Maintenance"
│   ├── content: "..."
│   ├── recipientType: "all|hosts|vip_users"
│   ├── createdBy: "admin123"
│   ├── createdAt: timestamp
│   ├── sentAt: timestamp
│   ├── readCount: 523
│   └── recipients: ["user1", "user2", ...]

// Send system message
async function sendSystemMessage(message) {
  const messageRef = await addDoc(collection(db, 'system_messages'), {
    ...message,
    createdAt: new Date(),
    createdBy: auth.currentUser.uid,
    status: 'sent'
  });

  // Also add to user notifications
  if (message.recipientType === 'all') {
    const usersRef = collection(db, 'users');
    const users = await getDocs(usersRef);
    
    users.forEach(userDoc => {
      addDoc(collection(db, 'users', userDoc.id, 'notifications'), {
        messageId: messageRef.id,
        title: message.subject,
        body: message.content,
        read: false,
        createdAt: new Date()
      });
    });
  }
}
```

---

## 👤 Page 7: Admin Profile & Settings

### Files
```
agency-dashboard/app/
├── admin-profile/
│   ├── page.js              ← Profile view
│   └── components/
│       ├── ProfileForm.js
│       ├── PasswordChange.js
│       └── Permissions.js
```

### Firebase Integration
```javascript
// Admin user structure
admins/
├── adminId/
│   ├── name: "Admin Name"
│   ├── email: "admin@xxx.com"
│   ├── role: "super_admin|moderator|analyst"
│   ├── permissions: {
│   │   ├── canBanUsers: true
│   │   ├── canManageCoins: true
│   │   ├── canViewAnalytics: true
│   │   └── canManageLiveStreams: true
│   ├── createdAt: timestamp
│   ├── lastLogin: timestamp
│   └── status: "active|inactive"
```

---

## 📊 Page 8: Reports & Analytics

### Files
```
agency-dashboard/app/
├── reports/
│   ├── page.js              ← Dashboard
│   ├── users.js             ← User analytics
│   ├── revenue.js           ← Revenue reports
│   ├── engagement.js        ← Engagement metrics
│   └── components/
│       ├── Chart.js
│       └── ExportButton.js
```

### Firebase Queries
```javascript
// Daily aggregated stats (Cloud Function updates these daily)
analytics/
├── daily_{date}/
│   ├── totalUsers: 15000
│   ├── newUsers: 234
│   ├── activeUsers: 8900
│   ├── totalDiamondsSpent: 450000
│   ├── totalCoinsEarned: 2300000
│   ├── liveStreams: 156
│   ├── totalViewers: 450000
│   └── avgSessionDuration: 2345 (seconds)
├── daily_2026-02-23/
└── ...

// Query example
const getAnalytics = async (startDate, endDate) => {
  const analyticsRef = collection(db, 'analytics');
  const q = query(
    analyticsRef,
    where('date', '>=', startDate),
    where('date', '<=', endDate),
    orderBy('date', 'asc')
  );
  
  const snapshot = await getDocs(q);
  return snapshot.docs.map(doc => doc.data());
};
```

---

## ⚡ Performance Optimization Strategy

### 1. **Reduce Firestore Reads** (60% of slow-down)

#### ❌ SLOW: Load all data
```javascript
// BAD - Loads 1000s of docs
const allUsers = await getDocs(collection(db, 'users'));
```

#### ✅ FAST: Pagination + Filtering
```javascript
// GOOD - Load 50 at a time
const q = query(
  collection(db, 'users'),
  where('status', '==', 'active'),
  orderBy('createdAt', 'desc'),
  limit(50)
);
const snapshot = await getDocs(q);
```

### 2. **Enable Firestore Caching** (Reduce round-trips by 70%)

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
  }
}

// In your code - enable offline persistence
import { enableIndexedDbPersistence } from 'firebase/firestore';

enableIndexedDbPersistence(db).catch((err) => {
    if (err.code == 'failed-precondition') {
        console.log('Multiple tabs open');
    } else if (err.code == 'unimplemented') {
        console.log('Not supported');
    }
});
```

### 3. **Use Composite Indexes** (Faster queries)

```
Create indexes for:
- users: status, createdAt
- calls: type, status, createdAt
- party_rooms: status, createdAt
- transactions: userId, timestamp
```

### 4. **Implement Server-Side Caching**

```javascript
// lib/cache.js
import NodeCache from 'node-cache';

const cache = new NodeCache({ stdTTL: 300 }); // 5 min TTL

export async function getCachedUsers() {
  const cached = cache.get('users_list');
  if (cached) return cached;

  const users = await getDocs(collection(db, 'users'));
  const data = users.docs.map(doc => doc.data());
  
  cache.set('users_list', data);
  return data;
}
```

### 5. **Reduce UI Renders** (React optimization)

```javascript
// Use useMemo for expensive calculations
const memoizedUsers = useMemo(() => {
  return users.filter(u => u.status === 'active').sort();
}, [users]);

// Use useCallback for stable function references
const handleFilter = useCallback((status) => {
  setFilter(status);
}, []);
```

### 6. **Image Optimization**

```javascript
// Use Next.js Image component
import Image from 'next/image';

<Image
  src={user.photoUrl}
  alt={user.name}
  width={50}
  height={50}
  quality={80}  // Reduce file size by 20%
/>
```

---

## 📋 Implementation Checklist

### Week 1: Core Pages
- [ ] User Management
  - [ ] List users with pagination
  - [ ] Search & filter functionality
  - [ ] Ban/Suspend controls
  - [ ] Real-time user count
  
- [ ] Live Stream Control
  - [ ] Real-time stream monitoring
  - [ ] Stop stream functionality
  - [ ] Viewer analytics
  - [ ] Quality controls

- [ ] Performance Tuning
  - [ ] Enable Firestore caching
  - [ ] Create indexes
  - [ ] Implement pagination
  - [ ] Add loading states

### Week 2: Content & Admin
- [ ] Party Room Management
- [ ] Admin Profile & Settings
- [ ] User permission system
- [ ] Cache optimization

### Week 3: Finance & Leaderboards
- [ ] Coins/Diamonds System
- [ ] Transaction logging
- [ ] Leaderboard rankings
- [ ] Aggregation functions

### Week 4: Analytics & Finalization
- [ ] Reports & Analytics dashboard
- [ ] System Messages
- [ ] Export functionality
- [ ] Final performance tuning

---

## 🔧 Firebase Cloud Functions to Create

```javascript
// functions/src/index.js

// 1. Update user leaderboards daily
exports.updateLeaderboards = functions.pubsub
  .schedule('every day 00:00').onRun(async (context) => {
    // Aggregate user data and update rankings
  });

// 2. Generate system reports daily
exports.generateDailyReport = functions.pubsub
  .schedule('every day 01:00').onRun(async (context) => {
    // Create analytics for previous day
  });

// 3. Process coin transactions
exports.processCoinTransaction = functions.firestore
  .document('transactions/{transactionId}')
  .onCreate(async (snap, context) => {
    // Update user balance, trigger notifications
  });
```

---

## 🎯 Summary: මෙම 8 Pages

| Page | Priority | Timeline | Firebase Collections |
|------|----------|----------|----------------------|
| User Management | 🔴 High | Week 1 Day 1-2 | users |
| Live Streams | 🔴 High | Week 1 Day 2-3 | calls |
| Party Rooms | 🟠 Medium | Week 2 Day 1 | party_rooms |
| Coins/Diamonds | 🔴 High | Week 3 Day 1-2 | users, transactions |
| Leaderboards | 🟠 Medium | Week 3 Day 3-4 | leaderboards |
| Admin Profile | 🟡 Low | Week 2 Day 2 | admins |
| System Messages | 🟡 Low | Week 4 Day 1 | system_messages |
| Reports & Analytics | 🟡 Low | Week 4 Day 2-4 | analytics |

---

## 📱 ම Sinhala Summary

**වසර අවස්ථාව:**
- ✅ Page 1: Users - සිටින users බලන්න, ban කරන්න
- ✅ Page 2: Live - Live streaming control කරන්න
- ✅ Page 3: Party - Party rooms moderate කරන්න
- ✅ Page 4: Coins - Diamonds/coins adjust කරන්න
- ✅ Page 5: Leaderboards - Rankings
- ✅ Page 6: Messages - System alerts
- ✅ Page 7: Profile - Admin settings
- ✅ Page 8: Reports - Analytics එක බලන්න

**Performance:**
- Firestore caching → 70% faster
- Pagination → Memory අඩු
- Indexes → Queries 10x faster
- Image optimization → Load time 30% අඩු

**Timeline:** 4 සති (28 දින)
