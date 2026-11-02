package io.flutter.plugins.inapppurchase;

import static org.junit.Assert.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import com.android.billingclient.api.*;
import java.lang.reflect.Field;
import java.time.Duration;
import java.util.*;
import java.util.concurrent.atomic.AtomicInteger;
import kotlin.Result;
import kotlin.Unit;
import kotlin.jvm.functions.Function1;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;
import org.robolectric.shadows.ShadowSystemClock;

@RunWith(RobolectricTestRunner.class)
@Config(manifest = Config.NONE, sdk = 35)
public class NativeProductCacheTest {
  private MethodCallHandlerImpl handler;
  private final List<ProductDetailsResponseListener> requests = new ArrayList<>();
  private final PlatformQueryProduct sku = new PlatformQueryProduct("sku", PlatformProductType.INAPP);
  private final AtomicInteger completions = new AtomicInteger();
  private Function1<? super Result<PlatformProductDetailsResponse>, Unit> callback() {
    return result -> { completions.incrementAndGet(); return Unit.INSTANCE; };
  }
  private ProductDetails product(String name) {
    ProductDetails p = mock(ProductDetails.class);
    when(p.getProductId()).thenReturn("sku");
    when(p.getProductType()).thenReturn("inapp");
    when(p.getTitle()).thenReturn(name);
    when(p.getName()).thenReturn(name);
    when(p.getDescription()).thenReturn("");
    return p;
  }
  private void reply(int index, ProductDetails p) {
    requests.get(index).onProductDetailsResponse(
      BillingResult.newBuilder().setResponseCode(BillingClient.BillingResponseCode.OK).build(),
      QueryProductDetailsResult.create(Collections.singletonList(p), Collections.emptyList()));
  }
  @Before public void setup() throws Exception {
    handler = new MethodCallHandlerImpl(null, null, mock(InAppPurchaseCallbackApi.class), mock(BillingClientFactory.class));
    BillingClient client = mock(BillingClient.class);
    Field field = MethodCallHandlerImpl.class.getDeclaredField("billingClient");
    field.setAccessible(true); field.set(handler, client);
    doAnswer(invocation -> { requests.add(invocation.getArgument(1)); return null; })
      .when(client).queryProductDetailsAsync(any(), any());
  }
  @Test public void cacheRemainsUntilExplicitRefresh() {
    handler.loadProductDetailsAsync(sku, false, callback());
    assertEquals(1, requests.size()); reply(0, product("first"));
    handler.loadProductDetailsAsync(sku, false, callback());
    assertEquals(1, requests.size()); assertEquals(2, completions.get());
    ShadowSystemClock.advanceBy(Duration.ofDays(7));
    handler.loadProductDetailsAsync(sku, false, callback());
    assertEquals(1, requests.size());
    assertEquals(3, completions.get());
    handler.loadProductDetailsAsync(sku, true, callback());
    assertEquals(2, requests.size());
    reply(1, product("refreshed"));
    assertEquals("refreshed", handler.getCachedProductDetails(sku).getTitle());
  }
  @Test public void concurrentNormalAndForcedRequestsCoalesce() {
    handler.loadProductDetailsAsync(sku, false, callback());
    handler.loadProductDetailsAsync(sku, false, callback());
    assertEquals(1, requests.size()); reply(0, product("first"));
    assertEquals(2, completions.get());
    handler.loadProductDetailsAsync(sku, true, callback());
    handler.loadProductDetailsAsync(sku, true, callback());
    assertEquals(2, requests.size()); reply(1, product("fresh"));
    assertEquals(4, completions.get());
    assertEquals("fresh", handler.getCachedProductDetails(sku).getTitle());
  }
  @Test public void invalidatedLateQueryCannotReplaceFreshProduct() {
    handler.loadProductDetailsAsync(sku, false, callback());
    handler.invalidateProductDetails(Collections.singletonList("sku"));
    handler.loadProductDetailsAsync(sku, false, callback());
    reply(1, product("new")); reply(0, product("old"));
    assertEquals("new", handler.getCachedProductDetails(sku).getTitle());
    assertEquals(2, completions.get());
  }
  @Test public void simultaneousTypeProbesDoNotInvalidateEachOther() {
    handler.queryProductDetailsAsync(Collections.singletonList(sku), callback());
    handler.queryProductDetailsAsync(Collections.singletonList(new PlatformQueryProduct("sku", PlatformProductType.SUBS)), callback());
    reply(0, product("valid-inapp"));
    requests.get(1).onProductDetailsResponse(
      BillingResult.newBuilder().setResponseCode(BillingClient.BillingResponseCode.OK).build(),
      QueryProductDetailsResult.create(Collections.emptyList(), Collections.emptyList()));
    assertEquals(2, completions.get());
    assertEquals("valid-inapp", handler.getCachedProductDetails(sku).getTitle());
  }
  @Test public void refreshDoesNotRemoveThePurchasableCachedProduct() {
    handler.loadProductDetailsAsync(sku, false, callback()); reply(0, product("old"));
    handler.loadProductDetailsAsync(sku, true, callback());
    assertEquals("old", handler.getCachedProductDetails(sku).getTitle());
    handler.loadProductDetailsAsync(sku, false, callback());
    assertEquals(2, requests.size());
    reply(1, product("new"));
    assertEquals("new", handler.getCachedProductDetails(sku).getTitle());
  }
  @Test public void wrongTypeAndGlobalInvalidationCannotReuseProduct() {
    handler.loadProductDetailsAsync(sku, false, callback()); reply(0, product("first"));
    assertNull(handler.getCachedProductDetails(new PlatformQueryProduct("sku", PlatformProductType.SUBS)));
    handler.invalidateProductDetails(null);
    assertNull(handler.getCachedProductDetails(sku));
  }
}
