require 'bigdecimal'
require 'bigdecimal/util'

TABLE_LINE = "+".ljust(49,'-') + "+".ljust(11,'-') + "+\n"
MIN_PRICE = '0.01'.to_d
MAX_PRICE = '999.99'.to_d

class Numeric
  def to_o
    cardinal = self.to_i.abs
    if (10...20).include?(cardinal) then
      cardinal.to_s << 'th'
    else
      cardinal.to_s << %w{th st nd rd th th th th th th}[cardinal % 10]
    end
  end
end

module Discounts
  def self.give_me(description)
    name, params = description.first
    case name
      when :get_one_free then NthDiscount.new params
      when :package then PackDiscount.new params
      when :threshold then ThresholdDiscount.new params
      else DummyDiscount.new
    end
  end

  def self.sum_it_up(verbal, value)
        "|   %-45s|%9.2f |\n" % [verbal, value]
  end

  class NthDiscount
    def initialize(needed_for_disctount)
      @needed = needed_for_disctount
    end

    def discount_value(item_price, item_count)
      -( (item_count / @needed) * item_price ) 
    end

    def to_s(item_price, item_count)
      text = "(buy %1.0f, get 1 free)" % [@needed - 1]
      value = discount_value item_price, item_count
      Discounts.sum_it_up text, value
    end
  end

  class PackDiscount
    def initialize(pack_description)
      @pack_size, @percentage = pack_description.first
      @discount_factor = @percentage / '100.0'.to_d
    end

    def discount_value(item_price, item_count)
      -(item_price  * (item_count / @pack_size) * @pack_size * @discount_factor)
    end

    def to_s(item_price, item_count)
      text = "(get %1.0f%% off for every %1.0f)" % [@percentage,@pack_size]
      value = discount_value item_price, item_count
      Discounts.sum_it_up text, value
    end
  end

  class ThresholdDiscount
    def initialize(set_threshold)
      @threshold, @percent = set_threshold.first
      @discount_factor = @percent / '100.00'.to_d
    end

    def discount_value(item_price, item_count)
      return '0.00'.to_d unless item_count > @threshold
      -((item_count - @threshold) * item_price * @discount_factor)
    end

    def to_s(item_price, item_count)
      text = "(%1.0f%% off of every after the %s)" % [@percent, @threshold.to_o]
      value = discount_value item_price, item_count
      Discounts.sum_it_up text, value
    end
  end

  class DummyDiscount
    def discount_value(unused_price, unused_count)
      0.0
    end

    def to_s(first_dummy, second_dummy)
      ''
    end
  end
end

module Coupons
  def self.give_me(coupon_name, coupon_type, value)
    case coupon_type
      when :percent then PercentCoupon.new coupon_name, value
      when :amount then FixedCoupon.new coupon_name, value
    end
  end

  class FixedCoupon
    def initialize(name, amount)
      @amount = amount.to_d
      @name = name
    end

    def apply(original_amount)
      @amount < original_amount ? -@amount : -original_amount
    end

    def to_s
      "Coupon %s - %1.2f off" % [@name, @amount]
    end
  end

  class PercentCoupon
    def initialize(name, percent)
      @percent = percent
      @koef = percent / '100.00'.to_d
      @name = name
    end

    def apply(original_amount)
      -(original_amount * @koef)
    end

    def to_s
      "Coupon %s - %1.0f%% off" % [@name, @percent]
    end
  end
end

class CartItem
  attr_reader :item, :quantity 
  def initialize(item)
    @item = item
    @quantity = 0
  end 

  def total
    @item.price * @quantity
  end

  def add(how_much)
    raise 'Don`t get greedy!' unless @quantity + how_much < 100
    @quantity += how_much
  end

  def total_discount
    @item.discount.discount_value(@item.price, @quantity)
  end

  def to_s
    discount_line = @item.discount.to_s @item.price, @quantity
    "| %-40s%6.0f |%9.2f |\n" % [@item.name, @quantity, total] + discount_line
  end
end

class InventoryItem
  attr_reader :name, :price, :discount
  def initialize(item_name, item_price, the_discount = {})
    @name, @price = item_name, item_price
    @discount = Discounts.give_me the_discount
  end
end

class ItemCart
  def initialize(parent)
    @inventory = parent
    @item_list = {}
    @discount = nil
  end
  
  def add(item_name, item_quantity = 1)
    raise 'Can`t sell that!' unless @inventory.item_registered? item_name
    raise 'We don`t do returns!' if item_quantity < 1
    unless @item_list.has_key? item_name
      @item_list[item_name] = CartItem.new(@inventory.get_item item_name)
    end
    @item_list[item_name].add item_quantity
  end

  def total
    raw_sum + (@discount.nil? ? '0.00'.to_d : @discount.apply(raw_sum))
  end

  def raw_sum
    @item_list.values.inject ('0.00'.to_d) do |sum, item| 
      sum + item.total + item.total_discount
    end
  end

  def invoice
    to_return = TABLE_LINE
    to_return += "| %-40s%6s |%9s |\n" % ['Name', 'qty', 'price'] + TABLE_LINE
    to_return += @item_list.values.inject('') do |so_far, item| 
      so_far + item.to_s
    end
    to_return += get_coupon_line + TABLE_LINE 
    to_return += "| %-47s|%9.2f |\n" % ['TOTAL', total] + TABLE_LINE
  end

  def get_coupon_line
    return '' if @discount.nil?
    "| %-47s|%9.2f |\n" % [@discount.to_s, @discount.apply(raw_sum)]
  end

  def use(coupon_name)
    raise 'You`re getting greedy again!' unless @discount.nil?
    @discount = @inventory.get_coupon coupon_name
    raise 'No such coupon!' if @discount.nil?
  end
end

class Inventory
  def initialize
    @registered_items = []
    @registered_coupons = {}
  end
  
  def register(item_name, item_price, discount_type = { :dummy => nil })
    raise 'Give me a name, not a novell!' if item_name.length > 40
    item_price = item_price.to_d
    raise 'Reevaluate it!' if (item_price < MIN_PRICE or item_price > MAX_PRICE)
    raise 'I`ve seen that one already!' if item_registered? item_name
    @registered_items << InventoryItem.new(item_name, item_price, discount_type)
  end

  def register_coupon(coupon_name, bonus)
    raise 'Enough already!' if @registered_coupons.has_key? coupon_name
    @registered_coupons[coupon_name] = Coupons.give_me coupon_name, *bonus.first
  end

  def item_registered?(item_name)
    @registered_items.any? { |item| item.name  == item_name }
  end

  def new_cart
    ItemCart.new self
  end

  def get_item(item_name)
    @registered_items.detect { |item| item.name == item_name }
  end

  def get_coupon(coupon_name)
    @registered_coupons[coupon_name]
  end
end
