import { describe, it, expect, beforeEach, vi } from 'vitest';

// Mock the Clarity contract environment
const mockContractEnv = () => {
  const state = {
    suppliers: new Map(),
    ethicalStandards: new Map(),
    supplierCompliance: new Map(),
    admin: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
    txSender: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
    blockHeight: 100
  };
  
  return {
    state,
    setTxSender: (sender) => { state.txSender = sender; },
    incrementBlockHeight: () => { state.blockHeight++; },
    
    // Contract functions
    registerSupplier: (supplierId, name) => {
      if (state.txSender !== state.admin) {
        return { err: 100 }; // ERR-NOT-AUTHORIZED
      }
      
      if (state.suppliers.has(supplierId)) {
        return { err: 101 }; // ERR-SUPPLIER-EXISTS
      }
      
      state.suppliers.set(supplierId, {
        name,
        verified: false,
        ethicalScore: 0,
        verificationDate: 0,
        verifier: state.txSender
      });
      
      return { ok: true };
    },
    
    verifySupplier: (supplierId, ethicalScore) => {
      if (state.txSender !== state.admin) {
        return { err: 100 }; // ERR-NOT-AUTHORIZED
      }
      
      if (!state.suppliers.has(supplierId)) {
        return { err: 102 }; // ERR-SUPPLIER-NOT-FOUND
      }
      
      const supplier = state.suppliers.get(supplierId);
      supplier.verified = true;
      supplier.ethicalScore = ethicalScore;
      supplier.verificationDate = state.blockHeight;
      supplier.verifier = state.txSender;
      
      state.suppliers.set(supplierId, supplier);
      
      return { ok: true };
    },
    
    addEthicalStandard: (standardId, name, description, requiredScore) => {
      if (state.txSender !== state.admin) {
        return { err: 100 }; // ERR-NOT-AUTHORIZED
      }
      
      if (state.ethicalStandards.has(standardId)) {
        return { err: 103 }; // ERR-STANDARD-EXISTS
      }
      
      state.ethicalStandards.set(standardId, {
        name,
        description,
        requiredScore
      });
      
      return { ok: true };
    },
    
    recordCompliance: (supplierId, standardId, compliant, evidenceHash) => {
      if (state.txSender !== state.admin) {
        return { err: 100 }; // ERR-NOT-AUTHORIZED
      }
      
      if (!state.suppliers.has(supplierId)) {
        return { err: 102 }; // ERR-SUPPLIER-NOT-FOUND
      }
      
      if (!state.ethicalStandards.has(standardId)) {
        return { err: 104 }; // ERR-STANDARD-NOT-FOUND
      }
      
      const key = `${supplierId}-${standardId}`;
      state.supplierCompliance.set(key, {
        compliant,
        evidenceHash,
        verificationDate: state.blockHeight
      });
      
      return { ok: true };
    },
    
    checkCompliance: (supplierId, standardId) => {
      const key = `${supplierId}-${standardId}`;
      return state.supplierCompliance.get(key) || {
        compliant: false,
        evidenceHash: '0x0000000000000000000000000000000000000000000000000000000000000000',
        verificationDate: 0
      };
    },
    
    getSupplier: (supplierId) => {
      return state.suppliers.get(supplierId) || null;
    },
    
    transferAdmin: (newAdmin) => {
      if (state.txSender !== state.admin) {
        return { err: 100 }; // ERR-NOT-AUTHORIZED
      }
      
      state.admin = newAdmin;
      return { ok: true };
    }
  };
};

describe('Supplier Verification Contract', () => {
  let contract;
  
  beforeEach(() => {
    contract = mockContractEnv();
  });
  
  it('should register a new supplier', () => {
    const result = contract.registerSupplier('supplier-001', 'Eco Fabrics Inc');
    expect(result).toEqual({ ok: true });
    
    const supplier = contract.getSupplier('supplier-001');
    expect(supplier).toEqual({
      name: 'Eco Fabrics Inc',
      verified: false,
      ethicalScore: 0,
      verificationDate: 0,
      verifier: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM'
    });
  });
  
  it('should not allow non-admin to register a supplier', () => {
    contract.setTxSender('ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG');
    const result = contract.registerSupplier('supplier-002', 'Green Cotton Co');
    expect(result).toEqual({ err: 100 }); // ERR-NOT-AUTHORIZED
  });
  
  it('should not allow registering a supplier that already exists', () => {
    contract.registerSupplier('supplier-001', 'Eco Fabrics Inc');
    const result = contract.registerSupplier('supplier-001', 'Duplicate Supplier');
    expect(result).toEqual({ err: 101 }); // ERR-SUPPLIER-EXISTS
  });
  
  it('should verify a supplier', () => {
    contract.registerSupplier('supplier-001', 'Eco Fabrics Inc');
    const result = contract.verifySupplier('supplier-001', 4);
    expect(result).toEqual({ ok: true });
    
    const supplier = contract.getSupplier('supplier-001');
    expect(supplier.verified).toBe(true);
    expect(supplier.ethicalScore).toBe(4);
    expect(supplier.verificationDate).toBe(100); // Current block height
  });
  
  it('should add an ethical standard', () => {
    const result = contract.addEthicalStandard(
        'standard-001',
        'Fair Trade',
        'Ensures fair compensation for workers',
        3
    );
    expect(result).toEqual({ ok: true });
  });
  
  it('should record supplier compliance with a standard', () => {
    // Setup
    contract.registerSupplier('supplier-001', 'Eco Fabrics Inc');
    contract.addEthicalStandard('standard-001', 'Fair Trade', 'Ensures fair compensation', 3);
    
    // Record compliance
    const evidenceHash = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
    const result = contract.recordCompliance('supplier-001', 'standard-001', true, evidenceHash);
    expect(result).toEqual({ ok: true });
    
    // Check compliance
    const compliance = contract.checkCompliance('supplier-001', 'standard-001');
    expect(compliance.compliant).toBe(true);
    expect(compliance.evidenceHash).toBe(evidenceHash);
    expect(compliance.verificationDate).toBe(100);
  });
  
  it('should transfer admin rights', () => {
    const newAdmin = 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG';
    const result = contract.transferAdmin(newAdmin);
    expect(result).toEqual({ ok: true });
    
    // Original admin can no longer perform admin actions
    const registerResult = contract.registerSupplier('supplier-002', 'Green Cotton Co');
    expect(registerResult).toEqual({ err: 100 }); // ERR-NOT-AUTHORIZED
    
    // New admin can perform admin actions
    contract.setTxSender(newAdmin);
    const newRegisterResult = contract.registerSupplier('supplier-002', 'Green Cotton Co');
    expect(newRegisterResult).toEqual({ ok: true });
  });
});
