# 🏥 Medical Consent Smart Contract

A blockchain-based medical consent management system built on the Stacks blockchain using Clarity smart contracts. This contract enables patients to securely grant and revoke access to their health data for healthcare providers with specific time periods and purposes.

## 🌟 Features

- 👤 **Patient Registration**: Patients can register with their personal information
- 🏥 **Provider Registration**: Healthcare providers can register and get verified
- ✅ **Consent Management**: Grant, revoke, and extend consent for data access
- 📊 **Access Logging**: Track all data access attempts with detailed logs
- ⏰ **Time-based Expiry**: Set expiration dates for consent permissions
- 🔒 **Purpose-specific Access**: Define specific purposes for data access
- 📋 **Data Type Control**: Specify which types of data can be accessed

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic understanding of Clarity smart contracts

### Installation

1. Clone this repository
2. Navigate to the project directory
3. Initialize Clarinet project (if not already done):

```bash
clarinet new medical-consent-project
```

4. Copy the contract file to `contracts/Medical-Consent-Contract.clar`

## 📖 Usage

### For Patients 👨‍⚕️

#### 1. Register as a Patient
```clarity
(contract-call? .Medical-Consent-Contract register-patient "John Doe" "john@email.com" "+1234567890")
```

#### 2. Grant Consent to a Provider
```clarity
(contract-call? .Medical-Consent-Contract grant-consent 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 
  "treatment" 
  u1000 
  (list "blood-test" "x-ray" "medical-history"))
```

#### 3. Revoke Consent
```clarity
(contract-call? .Medical-Consent-Contract revoke-consent 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 
  "treatment")
```

#### 4. Extend Consent Period
```clarity
(contract-call? .Medical-Consent-Contract extend-consent 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 
  "treatment" 
  u2000)
```

### For Healthcare Providers 🏥

#### 1. Register as a Provider
```clarity
(contract-call? .Medical-Consent-Contract register-provider 
  "City Hospital" 
  "LIC123456" 
  "Cardiology")
```

#### 2. Access Patient Data
```clarity
(contract-call? .Medical-Consent-Contract access-data 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 
  "treatment" 
  "Accessed blood test results for diagnosis")
```

### Read-Only Functions 📖

#### Check Consent Validity
```clarity
(contract-call? .Medical-Consent-Contract is-consent-valid 
  'PATIENT_ADDRESS 
  'PROVIDER_ADDRESS 
  "treatment")
```

#### Get Patient Information
```clarity
(contract-call? .Medical-Consent-Contract get-patient 'PATIENT_ADDRESS)
```

#### Get Consent Details
```clarity
(contract-call? .Medical-Consent-Contract get-consent 
  'PATIENT_ADDRESS 
  'PROVIDER_ADDRESS 
  "treatment")
```

## 🔧 Testing

Run the test suite using Clarinet:

```bash
clarinet test
```

## 📊 Contract Structure

### Data Maps
- **patients**: Store patient registration information
- **providers**: Store healthcare provider information  
- **consents**: Store consent permissions and metadata
- **access-logs**: Track all data access events

### Key Functions
- `register-patient`: Register a new patient
- `register-provider`: Register a healthcare provider
- `grant-consent`: Grant data access permission
- `revoke-consent`: Revoke existing consent
- `access-data`: Access patient data (providers only)
- `verify-provider`: Verify provider credentials (admin only)

## 🛡️ Security Features

- ✅ Only patients can grant/revoke their own consent
- ✅ Time-based expiration for all consents
- ✅ Purpose-specific access control
- ✅ Comprehensive access logging
- ✅ Provider verification system

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## ⚠️ Disclaimer

This smart contract is for educational and demonstration purposes. For production medical applications, ensure compliance with healthcare regulations like HIPAA, GDPR, and other applicable laws.
```

**Git Commit Message:**
```
feat: implement medical consent smart contract with patient data access control
```

**GitHub Pull Request Title:**
```
🏥 Add Medical Consent Smart Contract for Healthcare Data Management
```

**GitHub Pull Request Description:**
```
## Summary
Added a comprehensive medical consent management smart contract that enables patients to grant and revoke healthcare providers access to their medical data with time-based expiration and purpose-specific controls.

## Features Added
- ✅ Patient and provider registration system
- ✅ Consent granting/revoking functionality  
- ✅ Time-based consent expiration
- ✅ Purpose-specific data access control
- ✅ Comprehensive access logging
- ✅ Provider verification system
- ✅ Data type specification for granular control

##
