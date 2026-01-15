const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// Runs at 00:00 on the 25th of every month
exports.monthlySalaryTransition = functions.pubsub
    .schedule("0 0 25 * *")
    .timeZone("Asia/Colombo") // Set to Sri Lanka time
    .onRun(async (context) => {
      const db = admin.firestore();
      const now = new Date();

      // Calculate current and next month strings (e.g., 2026-01 and 2026-02)
      const currentYM = `${now.getFullYear()}-` +
          `${String(now.getMonth() + 1).padStart(2, "0")}`;
      const nextDate = new Date(now.getFullYear(), now.getMonth() + 1, 1);
      const nextYM = `${nextDate.getFullYear()}-` +
          `${String(nextDate.getMonth() + 1).padStart(2, "0")}`;

      const employees = await db.collection("emp-data").get();
      const batch = db.batch();

      for (const empDoc of employees.docs) {
        const fName = empDoc.data().first_name;
        const baseSalary = parseFloat(empDoc.data().salary) || 0;

        // Get current month record to check balance
        const currentRecord = await db.collection("salary-info")
            .where("first_name", "==", fName)
            .where("year_month", "==", currentYM)
            .limit(1).get();

        let carryForwardDebt = 0;

        if (!currentRecord.empty) {
          const data = currentRecord.docs[0].data();
          const balance = data.balance_amount || 0;

          if (balance < 0) {
          // Rule: Carry forward negative balance as an expense for next month
            carryForwardDebt = Math.abs(balance);
          } else if (balance > 0) {
          // Rule: Add positive balances to global monthly expenses
            const totExpRef = db.collection("monthly-tot-exp")
                .doc(`${now.getFullYear()}-${now.getMonth() + 1}`);

            batch.set(totExpRef, {
              "year": now.getFullYear(),
              "month": now.getMonth() + 1,
              "total-exp": admin.firestore.FieldValue.increment(balance),
              "timestamp": admin.firestore.FieldValue.serverTimestamp(),
            }, {merge: true});
          }
        }

        // Create next month's record
        const nextMonthRef = db.collection("salary-info").doc();
        batch.set(nextMonthRef, {
          first_name: fName,
          year_month: nextYM,
          base_salary: baseSalary,
          expenses: carryForwardDebt,
          balance_amount: baseSalary - carryForwardDebt,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      console.log(`Salary transition completed for ${nextYM}`);
      return null;
    });
