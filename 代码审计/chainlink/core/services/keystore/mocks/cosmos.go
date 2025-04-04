// Code generated by mockery v2.53.0. DO NOT EDIT.

package mocks

import (
	context "context"

	cosmoskey "github.com/smartcontractkit/chainlink/v2/core/services/keystore/keys/cosmoskey"

	mock "github.com/stretchr/testify/mock"
)

// Cosmos is an autogenerated mock type for the Cosmos type
type Cosmos struct {
	mock.Mock
}

type Cosmos_Expecter struct {
	mock *mock.Mock
}

func (_m *Cosmos) EXPECT() *Cosmos_Expecter {
	return &Cosmos_Expecter{mock: &_m.Mock}
}

// Add provides a mock function with given fields: ctx, key
func (_m *Cosmos) Add(ctx context.Context, key cosmoskey.Key) error {
	ret := _m.Called(ctx, key)

	if len(ret) == 0 {
		panic("no return value specified for Add")
	}

	var r0 error
	if rf, ok := ret.Get(0).(func(context.Context, cosmoskey.Key) error); ok {
		r0 = rf(ctx, key)
	} else {
		r0 = ret.Error(0)
	}

	return r0
}

// Cosmos_Add_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'Add'
type Cosmos_Add_Call struct {
	*mock.Call
}

// Add is a helper method to define mock.On call
//   - ctx context.Context
//   - key cosmoskey.Key
func (_e *Cosmos_Expecter) Add(ctx interface{}, key interface{}) *Cosmos_Add_Call {
	return &Cosmos_Add_Call{Call: _e.mock.On("Add", ctx, key)}
}

func (_c *Cosmos_Add_Call) Run(run func(ctx context.Context, key cosmoskey.Key)) *Cosmos_Add_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run(args[0].(context.Context), args[1].(cosmoskey.Key))
	})
	return _c
}

func (_c *Cosmos_Add_Call) Return(_a0 error) *Cosmos_Add_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *Cosmos_Add_Call) RunAndReturn(run func(context.Context, cosmoskey.Key) error) *Cosmos_Add_Call {
	_c.Call.Return(run)
	return _c
}

// Create provides a mock function with given fields: ctx
func (_m *Cosmos) Create(ctx context.Context) (cosmoskey.Key, error) {
	ret := _m.Called(ctx)

	if len(ret) == 0 {
		panic("no return value specified for Create")
	}

	var r0 cosmoskey.Key
	var r1 error
	if rf, ok := ret.Get(0).(func(context.Context) (cosmoskey.Key, error)); ok {
		return rf(ctx)
	}
	if rf, ok := ret.Get(0).(func(context.Context) cosmoskey.Key); ok {
		r0 = rf(ctx)
	} else {
		r0 = ret.Get(0).(cosmoskey.Key)
	}

	if rf, ok := ret.Get(1).(func(context.Context) error); ok {
		r1 = rf(ctx)
	} else {
		r1 = ret.Error(1)
	}

	return r0, r1
}

// Cosmos_Create_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'Create'
type Cosmos_Create_Call struct {
	*mock.Call
}

// Create is a helper method to define mock.On call
//   - ctx context.Context
func (_e *Cosmos_Expecter) Create(ctx interface{}) *Cosmos_Create_Call {
	return &Cosmos_Create_Call{Call: _e.mock.On("Create", ctx)}
}

func (_c *Cosmos_Create_Call) Run(run func(ctx context.Context)) *Cosmos_Create_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run(args[0].(context.Context))
	})
	return _c
}

func (_c *Cosmos_Create_Call) Return(_a0 cosmoskey.Key, _a1 error) *Cosmos_Create_Call {
	_c.Call.Return(_a0, _a1)
	return _c
}

func (_c *Cosmos_Create_Call) RunAndReturn(run func(context.Context) (cosmoskey.Key, error)) *Cosmos_Create_Call {
	_c.Call.Return(run)
	return _c
}

// Delete provides a mock function with given fields: ctx, id
func (_m *Cosmos) Delete(ctx context.Context, id string) (cosmoskey.Key, error) {
	ret := _m.Called(ctx, id)

	if len(ret) == 0 {
		panic("no return value specified for Delete")
	}

	var r0 cosmoskey.Key
	var r1 error
	if rf, ok := ret.Get(0).(func(context.Context, string) (cosmoskey.Key, error)); ok {
		return rf(ctx, id)
	}
	if rf, ok := ret.Get(0).(func(context.Context, string) cosmoskey.Key); ok {
		r0 = rf(ctx, id)
	} else {
		r0 = ret.Get(0).(cosmoskey.Key)
	}

	if rf, ok := ret.Get(1).(func(context.Context, string) error); ok {
		r1 = rf(ctx, id)
	} else {
		r1 = ret.Error(1)
	}

	return r0, r1
}

// Cosmos_Delete_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'Delete'
type Cosmos_Delete_Call struct {
	*mock.Call
}

// Delete is a helper method to define mock.On call
//   - ctx context.Context
//   - id string
func (_e *Cosmos_Expecter) Delete(ctx interface{}, id interface{}) *Cosmos_Delete_Call {
	return &Cosmos_Delete_Call{Call: _e.mock.On("Delete", ctx, id)}
}

func (_c *Cosmos_Delete_Call) Run(run func(ctx context.Context, id string)) *Cosmos_Delete_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run(args[0].(context.Context), args[1].(string))
	})
	return _c
}

func (_c *Cosmos_Delete_Call) Return(_a0 cosmoskey.Key, _a1 error) *Cosmos_Delete_Call {
	_c.Call.Return(_a0, _a1)
	return _c
}

func (_c *Cosmos_Delete_Call) RunAndReturn(run func(context.Context, string) (cosmoskey.Key, error)) *Cosmos_Delete_Call {
	_c.Call.Return(run)
	return _c
}

// EnsureKey provides a mock function with given fields: ctx
func (_m *Cosmos) EnsureKey(ctx context.Context) error {
	ret := _m.Called(ctx)

	if len(ret) == 0 {
		panic("no return value specified for EnsureKey")
	}

	var r0 error
	if rf, ok := ret.Get(0).(func(context.Context) error); ok {
		r0 = rf(ctx)
	} else {
		r0 = ret.Error(0)
	}

	return r0
}

// Cosmos_EnsureKey_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'EnsureKey'
type Cosmos_EnsureKey_Call struct {
	*mock.Call
}

// EnsureKey is a helper method to define mock.On call
//   - ctx context.Context
func (_e *Cosmos_Expecter) EnsureKey(ctx interface{}) *Cosmos_EnsureKey_Call {
	return &Cosmos_EnsureKey_Call{Call: _e.mock.On("EnsureKey", ctx)}
}

func (_c *Cosmos_EnsureKey_Call) Run(run func(ctx context.Context)) *Cosmos_EnsureKey_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run(args[0].(context.Context))
	})
	return _c
}

func (_c *Cosmos_EnsureKey_Call) Return(_a0 error) *Cosmos_EnsureKey_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *Cosmos_EnsureKey_Call) RunAndReturn(run func(context.Context) error) *Cosmos_EnsureKey_Call {
	_c.Call.Return(run)
	return _c
}

// Export provides a mock function with given fields: id, password
func (_m *Cosmos) Export(id string, password string) ([]byte, error) {
	ret := _m.Called(id, password)

	if len(ret) == 0 {
		panic("no return value specified for Export")
	}

	var r0 []byte
	var r1 error
	if rf, ok := ret.Get(0).(func(string, string) ([]byte, error)); ok {
		return rf(id, password)
	}
	if rf, ok := ret.Get(0).(func(string, string) []byte); ok {
		r0 = rf(id, password)
	} else {
		if ret.Get(0) != nil {
			r0 = ret.Get(0).([]byte)
		}
	}

	if rf, ok := ret.Get(1).(func(string, string) error); ok {
		r1 = rf(id, password)
	} else {
		r1 = ret.Error(1)
	}

	return r0, r1
}

// Cosmos_Export_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'Export'
type Cosmos_Export_Call struct {
	*mock.Call
}

// Export is a helper method to define mock.On call
//   - id string
//   - password string
func (_e *Cosmos_Expecter) Export(id interface{}, password interface{}) *Cosmos_Export_Call {
	return &Cosmos_Export_Call{Call: _e.mock.On("Export", id, password)}
}

func (_c *Cosmos_Export_Call) Run(run func(id string, password string)) *Cosmos_Export_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run(args[0].(string), args[1].(string))
	})
	return _c
}

func (_c *Cosmos_Export_Call) Return(_a0 []byte, _a1 error) *Cosmos_Export_Call {
	_c.Call.Return(_a0, _a1)
	return _c
}

func (_c *Cosmos_Export_Call) RunAndReturn(run func(string, string) ([]byte, error)) *Cosmos_Export_Call {
	_c.Call.Return(run)
	return _c
}

// Get provides a mock function with given fields: id
func (_m *Cosmos) Get(id string) (cosmoskey.Key, error) {
	ret := _m.Called(id)

	if len(ret) == 0 {
		panic("no return value specified for Get")
	}

	var r0 cosmoskey.Key
	var r1 error
	if rf, ok := ret.Get(0).(func(string) (cosmoskey.Key, error)); ok {
		return rf(id)
	}
	if rf, ok := ret.Get(0).(func(string) cosmoskey.Key); ok {
		r0 = rf(id)
	} else {
		r0 = ret.Get(0).(cosmoskey.Key)
	}

	if rf, ok := ret.Get(1).(func(string) error); ok {
		r1 = rf(id)
	} else {
		r1 = ret.Error(1)
	}

	return r0, r1
}

// Cosmos_Get_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'Get'
type Cosmos_Get_Call struct {
	*mock.Call
}

// Get is a helper method to define mock.On call
//   - id string
func (_e *Cosmos_Expecter) Get(id interface{}) *Cosmos_Get_Call {
	return &Cosmos_Get_Call{Call: _e.mock.On("Get", id)}
}

func (_c *Cosmos_Get_Call) Run(run func(id string)) *Cosmos_Get_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run(args[0].(string))
	})
	return _c
}

func (_c *Cosmos_Get_Call) Return(_a0 cosmoskey.Key, _a1 error) *Cosmos_Get_Call {
	_c.Call.Return(_a0, _a1)
	return _c
}

func (_c *Cosmos_Get_Call) RunAndReturn(run func(string) (cosmoskey.Key, error)) *Cosmos_Get_Call {
	_c.Call.Return(run)
	return _c
}

// GetAll provides a mock function with no fields
func (_m *Cosmos) GetAll() ([]cosmoskey.Key, error) {
	ret := _m.Called()

	if len(ret) == 0 {
		panic("no return value specified for GetAll")
	}

	var r0 []cosmoskey.Key
	var r1 error
	if rf, ok := ret.Get(0).(func() ([]cosmoskey.Key, error)); ok {
		return rf()
	}
	if rf, ok := ret.Get(0).(func() []cosmoskey.Key); ok {
		r0 = rf()
	} else {
		if ret.Get(0) != nil {
			r0 = ret.Get(0).([]cosmoskey.Key)
		}
	}

	if rf, ok := ret.Get(1).(func() error); ok {
		r1 = rf()
	} else {
		r1 = ret.Error(1)
	}

	return r0, r1
}

// Cosmos_GetAll_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'GetAll'
type Cosmos_GetAll_Call struct {
	*mock.Call
}

// GetAll is a helper method to define mock.On call
func (_e *Cosmos_Expecter) GetAll() *Cosmos_GetAll_Call {
	return &Cosmos_GetAll_Call{Call: _e.mock.On("GetAll")}
}

func (_c *Cosmos_GetAll_Call) Run(run func()) *Cosmos_GetAll_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run()
	})
	return _c
}

func (_c *Cosmos_GetAll_Call) Return(_a0 []cosmoskey.Key, _a1 error) *Cosmos_GetAll_Call {
	_c.Call.Return(_a0, _a1)
	return _c
}

func (_c *Cosmos_GetAll_Call) RunAndReturn(run func() ([]cosmoskey.Key, error)) *Cosmos_GetAll_Call {
	_c.Call.Return(run)
	return _c
}

// Import provides a mock function with given fields: ctx, keyJSON, password
func (_m *Cosmos) Import(ctx context.Context, keyJSON []byte, password string) (cosmoskey.Key, error) {
	ret := _m.Called(ctx, keyJSON, password)

	if len(ret) == 0 {
		panic("no return value specified for Import")
	}

	var r0 cosmoskey.Key
	var r1 error
	if rf, ok := ret.Get(0).(func(context.Context, []byte, string) (cosmoskey.Key, error)); ok {
		return rf(ctx, keyJSON, password)
	}
	if rf, ok := ret.Get(0).(func(context.Context, []byte, string) cosmoskey.Key); ok {
		r0 = rf(ctx, keyJSON, password)
	} else {
		r0 = ret.Get(0).(cosmoskey.Key)
	}

	if rf, ok := ret.Get(1).(func(context.Context, []byte, string) error); ok {
		r1 = rf(ctx, keyJSON, password)
	} else {
		r1 = ret.Error(1)
	}

	return r0, r1
}

// Cosmos_Import_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'Import'
type Cosmos_Import_Call struct {
	*mock.Call
}

// Import is a helper method to define mock.On call
//   - ctx context.Context
//   - keyJSON []byte
//   - password string
func (_e *Cosmos_Expecter) Import(ctx interface{}, keyJSON interface{}, password interface{}) *Cosmos_Import_Call {
	return &Cosmos_Import_Call{Call: _e.mock.On("Import", ctx, keyJSON, password)}
}

func (_c *Cosmos_Import_Call) Run(run func(ctx context.Context, keyJSON []byte, password string)) *Cosmos_Import_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run(args[0].(context.Context), args[1].([]byte), args[2].(string))
	})
	return _c
}

func (_c *Cosmos_Import_Call) Return(_a0 cosmoskey.Key, _a1 error) *Cosmos_Import_Call {
	_c.Call.Return(_a0, _a1)
	return _c
}

func (_c *Cosmos_Import_Call) RunAndReturn(run func(context.Context, []byte, string) (cosmoskey.Key, error)) *Cosmos_Import_Call {
	_c.Call.Return(run)
	return _c
}

// NewCosmos creates a new instance of Cosmos. It also registers a testing interface on the mock and a cleanup function to assert the mocks expectations.
// The first argument is typically a *testing.T value.
func NewCosmos(t interface {
	mock.TestingT
	Cleanup(func())
}) *Cosmos {
	mock := &Cosmos{}
	mock.Mock.Test(t)

	t.Cleanup(func() { mock.AssertExpectations(t) })

	return mock
}
