// Code generated by mockery v2.53.0. DO NOT EDIT.

package mocks

import (
	common "github.com/ethereum/go-ethereum/common"
	mock "github.com/stretchr/testify/mock"
)

// TokenPoolReader is an autogenerated mock type for the TokenPoolReader type
type TokenPoolReader struct {
	mock.Mock
}

type TokenPoolReader_Expecter struct {
	mock *mock.Mock
}

func (_m *TokenPoolReader) EXPECT() *TokenPoolReader_Expecter {
	return &TokenPoolReader_Expecter{mock: &_m.Mock}
}

// Address provides a mock function with no fields
func (_m *TokenPoolReader) Address() common.Address {
	ret := _m.Called()

	if len(ret) == 0 {
		panic("no return value specified for Address")
	}

	var r0 common.Address
	if rf, ok := ret.Get(0).(func() common.Address); ok {
		r0 = rf()
	} else {
		if ret.Get(0) != nil {
			r0 = ret.Get(0).(common.Address)
		}
	}

	return r0
}

// TokenPoolReader_Address_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'Address'
type TokenPoolReader_Address_Call struct {
	*mock.Call
}

// Address is a helper method to define mock.On call
func (_e *TokenPoolReader_Expecter) Address() *TokenPoolReader_Address_Call {
	return &TokenPoolReader_Address_Call{Call: _e.mock.On("Address")}
}

func (_c *TokenPoolReader_Address_Call) Run(run func()) *TokenPoolReader_Address_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run()
	})
	return _c
}

func (_c *TokenPoolReader_Address_Call) Return(_a0 common.Address) *TokenPoolReader_Address_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *TokenPoolReader_Address_Call) RunAndReturn(run func() common.Address) *TokenPoolReader_Address_Call {
	_c.Call.Return(run)
	return _c
}

// Type provides a mock function with no fields
func (_m *TokenPoolReader) Type() string {
	ret := _m.Called()

	if len(ret) == 0 {
		panic("no return value specified for Type")
	}

	var r0 string
	if rf, ok := ret.Get(0).(func() string); ok {
		r0 = rf()
	} else {
		r0 = ret.Get(0).(string)
	}

	return r0
}

// TokenPoolReader_Type_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'Type'
type TokenPoolReader_Type_Call struct {
	*mock.Call
}

// Type is a helper method to define mock.On call
func (_e *TokenPoolReader_Expecter) Type() *TokenPoolReader_Type_Call {
	return &TokenPoolReader_Type_Call{Call: _e.mock.On("Type")}
}

func (_c *TokenPoolReader_Type_Call) Run(run func()) *TokenPoolReader_Type_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run()
	})
	return _c
}

func (_c *TokenPoolReader_Type_Call) Return(_a0 string) *TokenPoolReader_Type_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *TokenPoolReader_Type_Call) RunAndReturn(run func() string) *TokenPoolReader_Type_Call {
	_c.Call.Return(run)
	return _c
}

// NewTokenPoolReader creates a new instance of TokenPoolReader. It also registers a testing interface on the mock and a cleanup function to assert the mocks expectations.
// The first argument is typically a *testing.T value.
func NewTokenPoolReader(t interface {
	mock.TestingT
	Cleanup(func())
}) *TokenPoolReader {
	mock := &TokenPoolReader{}
	mock.Mock.Test(t)

	t.Cleanup(func() { mock.AssertExpectations(t) })

	return mock
}
