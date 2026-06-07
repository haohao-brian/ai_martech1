# Wonderful Food Admin Password Standardization

**Date**: 2025-10-03
**Type**: Security Configuration Update
**Status**: ✅ COMPLETED

---

## 📋 Change Summary

Standardized admin account password across all wonderful_food applications for easier testing and demonstration purposes.

### Password Change
- **Old Password**: `admin123`
- **New Password**: `12345`
- **Username**: `admin` (unchanged)
- **Role**: `admin` (unchanged)

---

## 🎯 Reason for Change

**User Request**: "把管理員帳號統一變成：帳號：admin；密碼：12345"

### Justification
1. **Simplicity**: Easier to remember for demo/testing purposes
2. **Consistency**: All three wonderful_food apps use same credentials
3. **Development**: Streamlines local development and testing workflow

⚠️ **Security Note**: This is for **development/testing environments only**. Production deployments should use strong, unique passwords stored in environment variables or secrets management systems.

---

## 📁 Files Modified

### 1. wonderful_food_InsightForge_premium
**File**: `database/db_connection.R` (Lines 197-210)

**Before**:
```r
# 創建測試管理員用戶 (密碼: admin123)
dbExecute(con, "
  INSERT INTO users (username, hash, role, login_count)
  VALUES (?, ?, 'admin', 0)
", list("admin", bcrypt::hashpw("admin123")))
```

**After**:
```r
# 創建測試管理員用戶 (密碼: 12345)
dbExecute(con, "
  INSERT INTO users (username, hash, role, login_count)
  VALUES (?, ?, 'admin', 0)
", list("admin", bcrypt::hashpw("12345")))
```

**Console Output Changed**:
```r
cat("   管理員: admin / 12345\n")
```

---

### 2. wonderful_food_TagPilot_premium
**File**: `database/db_connection.R` (Lines 156-169)

**Before**:
```r
# 創建測試管理員用戶 (密碼: admin123)
dbExecute(con, "
  INSERT INTO users (username, hash, role, login_count)
  VALUES (?, ?, 'admin', 0)
", list("admin", bcrypt::hashpw("admin123")))
```

**After**:
```r
# 創建測試管理員用戶 (密碼: 12345)
dbExecute(con, "
  INSERT INTO users (username, hash, role, login_count)
  VALUES (?, ?, 'admin', 0)
", list("admin", bcrypt::hashpw("12345")))
```

**Console Output Changed**:
```r
cat("   管理員: admin / 12345\n")
```

---

### 3. wonderful_food_BrandEdge_premium
**File**: `database/db_connection.R` (Lines 146-170)

**Before**:
```r
# 創建測試管理員用戶 (密碼: admin123)
if (inherits(con, "SQLiteConnection")) {
  dbExecute(con, "
    INSERT INTO users (username, hash, role, login_count)
    VALUES ('admin', ?, 'admin', 0)
  ", list(bcrypt::hashpw("admin123")))
} else {
  dbExecute(con, "
    INSERT INTO users (username, hash, role, login_count)
    VALUES ($1, $2, 'admin', 0)
  ", list("admin", bcrypt::hashpw("admin123")))
}
```

**After**:
```r
# 創建測試管理員用戶 (密碼: 12345)
if (inherits(con, "SQLiteConnection")) {
  dbExecute(con, "
    INSERT INTO users (username, hash, role, login_count)
    VALUES ('admin', ?, 'admin', 0)
  ", list(bcrypt::hashpw("12345")))
} else {
  dbExecute(con, "
    INSERT INTO users (username, hash, role, login_count)
    VALUES ($1, $2, 'admin', 0)
  ", list("admin", bcrypt::hashpw("12345")))
}
```

**Console Output Changed**:
```r
cat("   管理員: admin / 12345\n")
```

---

## 🔐 Security Considerations

### Current Implementation (Development)
- ✅ Passwords are hashed using `bcrypt::hashpw()`
- ✅ Stored as bcrypt hashes in database
- ✅ Never stored in plain text
- ⚠️ Simple password for testing/demo only

### Production Deployment Recommendations

**DO NOT use simple passwords in production**. Instead:

1. **Environment Variables**:
   ```bash
   # In deployment platform (e.g., Posit Connect)
   ADMIN_PASSWORD=<strong-random-password>
   ```

2. **Secrets Management**:
   ```r
   # Use secrets manager in production
   admin_pass <- Sys.getenv("ADMIN_PASSWORD")
   if (!nzchar(admin_pass)) {
     stop("ADMIN_PASSWORD not set in environment")
   }
   ```

3. **Password Requirements** (Recommended for Production):
   - Minimum 12 characters
   - Mix of uppercase, lowercase, numbers, symbols
   - Regularly rotated
   - Unique per environment

---

## 📊 Impact Assessment

### Applications Affected
- ✅ wonderful_food_BrandEdge_premium
- ✅ wonderful_food_InsightForge_premium
- ✅ wonderful_food_TagPilot_premium

### User Accounts Updated
- ✅ Admin account: `admin` / `12345`
- ℹ️ Test user unchanged: `testuser` / `user123`

### Deployment Impact
- **Local Development**: ✅ Works immediately with new password
- **Existing Databases**: ⚠️ Will not update existing users (only creates new ones if count = 0)
- **Fresh Deployments**: ✅ Will use new password

---

## 🔄 Migration for Existing Databases

If you have existing databases with old admin password:

### Option 1: Delete and Recreate (Test Databases Only)
```sql
DELETE FROM users WHERE username = 'admin';
-- Restart app to recreate with new password
```

### Option 2: Update Password Directly
```r
# Connect to database
con <- get_con()

# Update admin password hash
new_hash <- bcrypt::hashpw("12345")
dbExecute(con, "
  UPDATE users
  SET hash = ?
  WHERE username = 'admin'
", list(new_hash))

dbDisconnect(con)
```

### Option 3: Reset Database (SQLite Only)
```bash
# Remove SQLite database file
rm -f insightforge_test.db
# Restart app to recreate with new credentials
```

---

## 📝 Updated Login Instructions

### For All Wonderful Food Apps

**Admin Login**:
- 帳號 (Username): `admin`
- 密碼 (Password): `12345`
- 角色 (Role): Admin (無登入次數限制)

**Test User Login**:
- 帳號 (Username): `testuser`
- 密碼 (Password): `user123`
- 角色 (Role): User (最多登入 5 次)

---

## 🎯 Future Improvements

### Short Term
- [ ] Add password strength validator for user registration
- [ ] Implement password change functionality for admin
- [ ] Add password expiry for non-admin users

### Medium Term
- [ ] Integrate with centralized authentication (OAuth, LDAP)
- [ ] Implement multi-factor authentication (MFA)
- [ ] Add password rotation policy

### Long Term
- [ ] Single Sign-On (SSO) integration
- [ ] Role-based access control (RBAC) refinement
- [ ] Audit logging for authentication events

---

## ✅ Verification Steps

To verify the password change:

1. **Start App**:
   ```r
   shiny::runApp()
   ```

2. **Check Console Output**:
   ```
   📝 創建測試用戶...
   ✅ 測試用戶創建完成
      管理員: admin / 12345
      一般用戶: testuser / user123
   ```

3. **Test Login**:
   - Navigate to login page
   - Enter username: `admin`
   - Enter password: `12345`
   - Should successfully authenticate

---

## 📚 Related Documentation

- **Users Table Schema**: `database/db_connection.R:92-98` (SQLite) or `130-137` (PostgreSQL)
- **Login Module**: `scripts/global_scripts/10_rshinyapp_components/login/login_module.R`
- **Authentication Logic**: Lines 119-146 in login_module.R
- **Password Hashing**: Uses `bcrypt::hashpw()` and `bcrypt::checkpw()`

---

## 🔍 Technical Notes

### Password Storage
- **Algorithm**: bcrypt
- **Library**: `bcrypt` R package
- **Hash Format**: Standard bcrypt hash string
- **Verification**: `bcrypt::checkpw(plain_password, stored_hash)`

### Database Trigger
Password update only occurs when:
```r
existing_users <- dbGetQuery(con, "SELECT COUNT(*) as count FROM users")
if (existing_users$count == 0) {
  # Create admin and testuser
}
```

This means:
- ✅ Fresh databases get new password
- ❌ Existing databases keep old password (requires manual update)

---

## ⚠️ Important Reminders

1. **Testing Only**: This simple password is for development/testing environments
2. **Production Security**: Use strong, unique passwords in production
3. **Environment Variables**: Store production credentials in secure environment variables
4. **Never Commit**: Never commit passwords to version control
5. **Regular Rotation**: Rotate admin passwords regularly in production

---

**Change Completed**: 2025-10-03
**Modified By**: Claude Code
**Verified**: Password change applied to all 3 wonderful_food applications
**Status**: ✅ READY FOR TESTING
