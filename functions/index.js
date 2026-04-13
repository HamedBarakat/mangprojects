const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

const db = getFirestore();

// ── Status label helper ───────────────────────────────────────────────────────
function statusLabel(status) {
  const map = {
    not_started:          'Not Started',
    in_progress:          'In Progress',
    team_leader_review:   'Team Leader Review',
    qc_review:            'QC Review',
    client_review:        'Client Review',
    completed:            'Completed ✅',
  };
  return map[status] ?? status;
}

// ── Fetch all FCM tokens for a list of user IDs ───────────────────────────────
async function getTokensForUsers(userIds) {
  const tokens = [];
  const unique = [...new Set(userIds.filter(Boolean))];

  await Promise.all(
    unique.map(async (uid) => {
      const snap = await db
        .collection('users')
        .doc(uid)
        .collection('fcmTokens')
        .get();
      snap.forEach((doc) => {
        const t = doc.data().token;
        if (t) tokens.push(t);
      });
    })
  );
  return tokens;
}

// ── Send FCM multicast, silently ignoring invalid tokens ─────────────────────
async function sendNotification(tokens, title, body, data = {}) {
  if (!tokens.length) return;

  const message = {
    notification: { title, body },
    data: Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, String(v)])
    ),
    tokens,
    webpush: {
      notification: {
        icon: '/icons/Icon-192.png',
        badge: '/icons/Icon-192.png',
      },
    },
  };

  try {
    const response = await getMessaging().sendEachForMulticast(message);
    console.log(`[FCM] sent=${response.successCount} failed=${response.failureCount}`);
  } catch (err) {
    console.error('[FCM] sendNotification error:', err);
  }
}

// ── Cloud Function: notify on task write ─────────────────────────────────────
exports.onTaskWritten = onDocumentWritten('tasks/{taskId}', async (event) => {
  const before = event.data.before?.data();
  const after  = event.data.after?.data();

  // Deletion — no push notification needed
  if (!after) return;

  const taskId   = event.params.taskId;
  const title    = after.title    ?? 'Unknown Task';
  const project  = after.projectName ?? '';
  const officeId = after.officeId ?? '';

  // Collect relevant recipients
  const recipientIds = [
    ...(after.engineerIds ?? []),
    after.teamLeaderId ?? '',
    after.reviewerId   ?? '',
  ].filter(Boolean);

  // Also include office-wide stakeholders (admin / management / DC / senior titles)
  if (officeId) {
    const usersSnap = await db
      .collection('users')
      .where('officeId', '==', officeId)
      .where('isActive', '==', true)
      .get();

    const stakeholderRoles  = new Set(['admin', 'dc', 'management']);
    const stakeholderTitles = new Set([
      'coo', 'principal_managing_partner',
      'technical_office_manager', 'head_of_department',
    ]);

    usersSnap.forEach((doc) => {
      const d = doc.data();
      if (
        d.adminFlag ||
        stakeholderRoles.has(d.role) ||
        stakeholderTitles.has(d.jobTitle)
      ) {
        recipientIds.push(doc.id);
      }
    });
  }

  // Task creation
  if (!before) {
    const tokens = await getTokensForUsers(recipientIds);
    await sendNotification(
      tokens,
      '🆕 New Task Assigned',
      `"${title}" was created in ${project}`,
      { taskId, projectId: after.projectId ?? '' }
    );
    return;
  }

  // Status change
  if (before.status !== after.status) {
    const tokens = await getTokensForUsers(recipientIds);
    await sendNotification(
      tokens,
      '📋 Task Status Updated',
      `"${title}" → ${statusLabel(after.status)}\n${project}`,
      { taskId, projectId: after.projectId ?? '', newStatus: after.status }
    );
  }
});
